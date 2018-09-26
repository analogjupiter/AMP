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
        ParserResult apiResult = parser.parse();
        auto html = new HTMLAPIDocsOutput(templatePath);
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

        //settings.blueprintFileDetails = blueprintFileDetails;
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
