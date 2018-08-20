/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    Linking this tool statically or dynamically with other modules is
    making a combined work based on this tool.  Thus, the terms and
    conditions of the GNU Affero General Public License cover the whole
    combination.

    As a special exception, the copyright holders of this tool give you
    permission to link this tool with independent modules to produce an
    executable, regardless of the license terms of these independent
    modules, and to copy and distribute the resulting executable under
    terms of your choice, provided that you also meet, for each linked
    independent module, the terms and conditions of the license of that
    module.  An independent module is a module which is not derived from
    or based on this tool.  If you modify this tool, you may extend
    this exception to your version of the tool, but you are not
    obligated to do so.  If you do not wish to do so, delete this
    exception statement from your version.
 +/
module amp.app;

import std.algorithm.iteration : filter;
import std.algorithm.searching : startsWith;
import std.file : readText, copy, dirEntries, DirEntry, exists, isDir, mkdirRecurse, SpanMode, thisExePath;
import std.getopt;
import std.path : baseName, buildPath, dirName, stripExtension;
import std.stdio;
import std.string;
import std.array : split, appender;

import amp.parser;
import amp.output.html;

enum ConfigFile = "amp.config";

/++
    Launches AMP in command-line mode
 +/
int runCLI(string[] args)
{
    bool optForceOverride;
    string optTemplateDirectory;
    bool optPrintVersionInfo;
    bool optUseStderr;
    bool optUseStdout;
    string blueprint;

    // dfmt off
    GetoptResult rgetopt = getopt(
        args,
        config.passThrough,
        "force|f", "Force override output file.", &optForceOverride,
        "stderr", "Redirect drafter logs to stderr", &optUseStderr,
        "stdout", "Use stdout instead of an output file. (Implies --stderr)", &optUseStdout,
        "templates|t", "Specifiy a custom template directory.", &optTemplateDirectory,
        "version|w", "Display the version of this program.", &optPrintVersionInfo
    );
    // dfmt on

    if (rgetopt.helpWanted)
    {
        defaultGetoptPrinter(import("appname.txt") ~ "\n\n  Usage:\n    " ~ args[0] ~
            " [options] [blueprint path] [output directory]\n\n\nAvailable options:\n==================", rgetopt.options);
        return 0;
    }
    else if (optPrintVersionInfo)
    {
        printVersionInfo();
        return 0;
    }

    if (optUseStdout)
    {
        optUseStderr = true;
    }

    // Blueprint path passed?
    if (args.length < 2)
    {
        // no
        stderr.writeln("\033[1;31mError: No blueprint path specified\033[39;49m");
        return 1;
    }

    // No template directory specified?
    if (optTemplateDirectory is null)
    {
        // Just use factory template
        optTemplateDirectory = thisExePath.dirName.buildPath("..", "factory-template");

        // Can the factory template be found?
        if (!optTemplateDirectory.buildPath(TemplateFileNameFull).exists)
        {
            // no
            stderr.writeln("\033[1;31mError: Factory template is missing; please specify a template directory.\033[39;49m");
            return 1;
        }
    }

    string path;
    File output;
    string outputPathAndBaseName;

    // Use stdout for output?
    if (!optUseStdout)
    {
        // no (file instead)
        // Create directory if it does not exist and copy template files

        // Output directory specified?
        if (args.length < 3)
        {
            // no
            stderr.writeln("\033[1;31mError: No output directory specified\033[39;49m");
            return 1;
        }

        path = args[$ - 2];
        immutable string outputDir = args[$ - 1];
        outputPathAndBaseName = outputDir.buildPath(path.baseName.stripExtension);
        immutable string outputPath = outputPathAndBaseName ~ ".html";

        // Does the output file already exists and should not be overriden?
        if (!optForceOverride && outputPath.exists)
        {
            // yes
            stderr.writeln("\033[1;31mError: Output file already exists. Use --force to override.\033[39;49m");
            return 1;
        }

        // Does the output directory exist?
        if (!outputDir.exists)
        {
            // no
            // so let's create it
            outputDir.mkdirRecurse();
        }

        // Verify directory
        if (!outputDir.isDir)
        {
            // the so-called directory is actually something else (probably an existing file)
            stderr.writeln("\033[1;31mError: The specified output directory is actually something else\033[39;49m");
            return 1;
        }

        output = File(outputPath, "w");

        // Copy template-related files into output directory
        foreach(DirEntry e; optTemplateDirectory.dirEntries(SpanMode.breadth))
        {
            // Don't copy hidden files
            if (e.baseName.startsWith('.'))
            {
                continue;
            }

            string target = outputDir.buildPath(e[(optTemplateDirectory.length + 1) .. $]);

            // Don't override already existing files
            if (!target.exists)
            {
                if (e.isDir)
                {
                    target.mkdirRecurse();
                }
                else
                {
                    e.copy(target);
                }
            }
            else if (!e.isDir)
            {
                // log
                stderr.writeln("\033[1;33mSkipping copying of template member `", e[(optTemplateDirectory.length + 1) .. $], "`\033[39;49m");
            }
        }
    }
    else
    {
        // yes (stdout)
        path = args[$ - 1];
        output = stdout;
    }

    // Verify path
    if (!exists(path))
    {
        stderr.writeln("\033[1;31mError: Non-existant blueprint path (" ~ path ~ ")\033[39;49m");
        return 1;
    }

    // Determine input path type (dir or file)
    // And read blueprint
    if (path.isDir)
    {
        // Read config file and concat all files specified in it

        string configPath = buildPath(path, ConfigFile);

        if(!exists(configPath))
        {
            stderr.writeln("\033[1;31mError: config file not found (" ~ configPath ~ ")
If you are using a directory, define a config file (amp.config) in it.
The config file should contain paths to all .apib files that you want to use.
The files will be concatenated in the specified sequence.\033[39;49m");
            return 1;
        }

        auto blueprintAppender = appender!string;

        foreach(string apibPath; getApibPaths(path))
        {
            blueprintAppender ~= readText(apibPath);    // TODO add support for CRLF

        }

        blueprint = blueprintAppender.data;
    }
    else
    {
        blueprint = readText(path);
    }

    // parse and render the blueprint
    if(blueprint.length == 0)
    {
        stderr.writeln("Warning: the blueprint is empty!");
        return 0;
    }

    File drafterLog = (optUseStderr) ? stderr : File(outputPathAndBaseName ~ ".drafterlog", "w");
    ParserResult r = blueprint.parseBlueprint(drafterLog);
    auto html = new HTMLAPIDocsOutput(optTemplateDirectory);
    html.write(r, output);

    return 0;
}

/++
    Prints AMP's version string
 +/
void printVersionInfo()
{
    writeln("AMP v", import("version.txt"));
}

/++
    Reads the paths from the config file
    and returns all paths that exist
+/
string[] getApibPaths(string path)
{
    string[] validPaths;
    stderr.writeln("debug");
    string configPath = buildPath(path, ConfigFile);

    string text = readText(configPath);
    string[] apibPaths = splitLines(text);

    foreach(string apibPath; apibPaths)
    {
        apibPath =  buildPath(path, apibPath);

        // The line is not empty
        if(apibPath.length > path.length)
        {
            if(exists(apibPath) && !apibPath.isDir)
            {
                validPaths ~= apibPath;
            }
            else
            {
                stderr.writeln("Warning: Ignored path (not found): (" ~ apibPath ~ ")");
            }
        }
    }

    return validPaths;
}
