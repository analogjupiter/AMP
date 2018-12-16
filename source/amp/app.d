/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
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
    writeln("AMP ", import("version.txt"));
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
