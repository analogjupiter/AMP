/++
    This file is part of AMP - API Markup Processor.
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
import std.file : copy, dirEntries, DirEntry, exists, isDir, mkdirRecurse, SpanMode, thisExePath;
import std.getopt;
import std.path : baseName, buildPath, dirName, stripExtension;
import std.stdio;

import amp.parser;
import amp.output.html;

/++
    Launches AMP in command-line mode
 +/
int runCLI(string[] args)
{
    bool optForceOverride;
    bool optUseStdout;
    string optTemplateDirectory;
    bool optPrintVersionInfo;


    // dfmt off
    GetoptResult rgetopt = getopt(
        args,
        config.passThrough,
        "force|f", "Force override output file.", &optForceOverride,
        "stdout", "Use stdout instead of an output file.", &optUseStdout,
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

    // Blueprint path passed?
    if (args.length < 2)
    {
        // no
        stderr.writeln("\033[1;31mError: No blueprint path specified");
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
            stderr.writeln("\033[1;31mError: Factory template is missing; please specify a template directory.");
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

        // Output directory specified?
        if (args.length < 3)
        {
            // no
            stderr.writeln("\033[1;31mError: No output directory specified");
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
            stderr.writeln("\033[1;31mError: Output file already exists. Use --force to override.");
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
            stderr.writeln("\033[1;31mError: The specified output directory is actually something else");
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
                stderr.writeln("\033[1;33mSkipping copying of template member `", e[(optTemplateDirectory.length + 1) .. $], "`");
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
        stderr.writeln("\033[1;31mError: Non-existant blueprint path (" ~ path ~ ")");
        return 1;
    }

    // Determine input path type (dir or file)
    if (path.isDir)
    {
        // Directory
        auto files = path.dirEntries("*.apib", SpanMode.shallow).filter!(a => a.isFile);

        if (!files.empty)
        {
            // concat before parsing (because of Drafter)
            assert(0, "Not implemented yet.");
        }
    }
    else
    {
        // File

        File drafterLog = (optUseStdout) ? stderr : File(outputPathAndBaseName ~ ".drafterlog", "w");

        ParserResult r = path.parseBlueprint(drafterLog);
        auto html = new HTMLAPIDocsOutput(optTemplateDirectory);
        html.write(r, output);
    }

    return 0;
}

/++
    Prints AMP's version string
 +/
void printVersionInfo()
{
    writeln("AMP v", import("version.txt"));
}

