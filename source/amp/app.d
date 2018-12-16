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
import std.typecons;
import core.stdc.stdlib;

import amp.parser;
import amp.output.html;
import amp.settings;
import amp.apidoc;

enum ConfigFileName = "amp.config";
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
        printHelp(args[0], rgetopt);
        return 0;
    }
    else if (optPrintVersionInfo)
    {
        printVersionInfo();
        return 0;
    }

    // Setup settings and render the blueprint

    // Blueprint path passed?
    if (args.length < 2)
    {
        stderr.writeln("\033[1;31mError: No blueprint path specified\033[39;49m");
        return 1;
    }

    // Init settings from args
    Settings settings = Settings.instance;
    settings.useStdout = optUseStdout;
    settings.useStderr = optUseStderr || optUseStdout; // useStdout also enables stderr
    settings.forceOverride = optForceOverride;
    settings.blueprintPath = settings.useStdout ? args[$ - 1] : args[$ - 2];
    settings.outputDirPath = getOutputDirPath(args);
    settings.outputHtmlPath = getOutputHtmlPath(args, settings.outputDirPath);
    settings.templateDirPath = getTemplatePath(optTemplateDirectory);
    settings.output = getOutputFile(settings);

    // Verify path
    if (!exists(settings.blueprintPath))
    {
        stderr.writeln("\033[1;31mError: Non-existant blueprint path (" ~ settings.blueprintPath ~ ")\033[39;49m");
        return 1;
    }

    parseAndRenderBlueprint(settings);
    copyTemplateFiles(settings);

    return 0;
}

void parseAndRenderBlueprint(Settings settings)
{
    File drafterLog = (settings.useStderr) ? stderr : File(settings.outputDirPath.buildPath(settings.projectName) ~ ".drafterlog", "w");
    auto apiDoc = new APIDocCreator(settings.blueprintPath, settings.templateDirPath, settings.output, drafterLog);

    apiDoc.create();
}

/++
    Prints AMP's version string
 +/
void printVersionInfo()
{
    writeln("AMP v", import("version.txt"));
}

void printHelp(string appPath, GetoptResult rgetopt)
{
    defaultGetoptPrinter(import("appname.txt") ~ "\n\n  Usage:\n    " ~ appPath ~
        " [options] [blueprint path] [output directory]\n\n\nAvailable options:\n==================", rgetopt.options);
}

File getOutputFile(Settings settings)
{
    if(settings.useStdout)
        return stdout;

    // Does the output file already exist and should not be overriden?
    if(!settings.forceOverride && settings.outputHtmlPath.exists)
    {
        stderr.writeln("\033[1;31mError: Output file already exists. Use --force to override.\033[39;49m");
        exit(1);
    }

    return File(settings.outputHtmlPath, "w");
}

string getTemplatePath(string templatePath)
{
    // No template directory specified?
    if (templatePath is null)
    {
        // Just use factory template
        templatePath = thisExePath.dirName.buildPath("..", "factory-template");
    }
    // Can the factory template be found?
    if (!templatePath.buildPath(TemplateFileNameFull).exists)
    {
        // no
        stderr.writeln("\033[1;31mError: Factory template is missing; please specify a template directory.\033[39;49m");
        exit(1);
    }

    return  templatePath;
}

void copyTemplateFiles(Settings settings)
{
    // Copy template-related files into output directory
    foreach(DirEntry source; settings.templateDirPath.dirEntries(SpanMode.breadth))
    {
        // Don't copy hidden files
        if (source.baseName.startsWith('.'))
        {
            continue;
        }

        string target = settings.outputDirPath.buildPath(source[(settings.templateDirPath.length + 1) .. $]);

        // Don't override already existing files
        if (!target.exists)
        {
            if (source.isDir)
            {
                target.mkdirRecurse();
            }
            else
            {
                source.copy(target);
            }
        }
        else if (!source.isDir)
        {
            // log
            stderr.writeln("\033[1;33mSkipping copying of template member `", source[(settings.templateDirPath.length + 1) .. $], "`\033[39;49m");
        }
    }
}

string getOutputDirPath(string[] args)
{
    // Output directory specified?
    if (args.length < 3)
    {
        stderr.writeln("\033[1;31mError: No output directory specified\033[39;49m");
        exit(1);
    }

    tryCreateOutputDir(args[$-1]);

    return args[$-1];
}

string getOutputHtmlPath(string[] args, string outputDirPath)
{
    string blueprintPath = args[$ - 2];
    string bluePrintProjectName = blueprintPath.baseName.stripExtension;
    immutable string outputDir = args[$ - 1];
    string outputHtmlPath = outputDir.buildPath(blueprintPath.baseName.stripExtension) ~ ".html";
    return outputHtmlPath;
}

void tryCreateOutputDir(string outputDir)
{
    if (!outputDir.exists)
    {
        outputDir.mkdirRecurse();
    }

    // Verify directory
    if (!outputDir.isDir)
    {
        stderr.writeln("\033[1;31mError: The specified output directory is actually something else\033[39;49m");
        exit(1);
    }
}
