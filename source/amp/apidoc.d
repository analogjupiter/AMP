/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
 +/
module amp.apidoc;

import std.algorithm.iteration : filter;
import std.algorithm.searching : startsWith;
import std.file : readText, copy, dirEntries, DirEntry, exists, isDir, isFile, mkdirRecurse, SpanMode, thisExePath;
import std.path : baseName, buildPath, dirName, stripExtension;
import std.stdio;
import std.string;
import std.array : split, appender;
import std.typecons;
import core.stdc.stdlib;

import amp.parser;
import amp.output.html;
import amp.settings;

enum ConfigFileName = "amp.config";

class APIDocCreator
{
    File errorLog;
    File output;
    string blueprintPath;
    string templatePath;

    Tuple!(string, ulong)[] blueprintFileDetails;

    public this(string blueprintPath, string templatePath, File output, File errorLog = stderr)
    {
        this.blueprintPath = blueprintPath;
        this.templatePath = templatePath;
        this.output = output;
        this.errorLog = errorLog;
    }

    public void create()
    {
        string blueprint = getBlueprint();
        if(blueprint.length == 0)
        {
            stderr.writeln("Warning: the blueprint is empty!");
            return;
        }

        BlueprintParser parser = new BlueprintParser(blueprint, errorLog, blueprintFileDetails);
        stderr.writeln("Info: Parsing the blueprint...");
        ParserResult apiResult = parser.parse();
        auto html = new HTMLAPIDocsOutput(templatePath);
        stderr.writeln("Info: Rendering the html...");
        html.write(apiResult, output);
    }

    private string getBlueprint()
    {
        if (blueprintPath.isDir)
            return getBlueprintFromDir();
        else if(blueprintPath.isFile)
            return getBlueprintFromFile();
        else
            return "";  // blueprint does not exist
    }

    private string getBlueprintFromFile()
    {
        return readText(blueprintPath);
    }

    private string getBlueprintFromDir()
    {
        // Read config file and concat all files specified in it

        string configPath = buildPath(blueprintPath, ConfigFileName);

        if(!exists(configPath))
        {
            stderr.writeln("\033[1;31mError: config file not found (" ~ configPath ~ ")
If you are using a directory, define a config file (amp.config) in it.
The config file should contain paths to all .apib files that you want to use.
The files will be concatenated in the specified sequence.\033[39;49m");
            exit(1);
        }

        auto blueprintAppender = appender!string;

        foreach(string apibPath; getApibPaths())
        {
            string blueprintText = readText(apibPath);
            blueprintFileDetails ~= tuple(apibPath, splitLines(blueprintText).length);
            blueprintAppender ~= blueprintText;    // TODO add support for CRLF
            blueprintAppender ~= "\n"; // avoid two lines merging to one
        }

        return blueprintAppender.data;
    }

    /++
        Reads the paths from the config file
        and returns all paths that exist
    +/
    string[] getApibPaths()
    {
        string[] validPaths;
        string configPath = buildPath(blueprintPath, ConfigFileName);

        string text = readText(configPath);
        string[] apibPaths = splitLines(text);

        foreach(string apibPath; apibPaths)
        {
            apibPath = buildPath(blueprintPath, apibPath);

            // The line is not empty
            if(apibPath.length > blueprintPath.length)
            {
                if(exists(apibPath) && !apibPath.isDir)
                {
                    validPaths ~= apibPath;
                }
                else
                {
                    stderr.writeln("Warning: Ignored path (not found or not a file): (" ~ apibPath ~ ")");
                }
            }
        }

        return validPaths;
    }
}
