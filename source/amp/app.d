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

import std.file : exists, isDir, mkdirRecurse, thisExePath;
import std.getopt;
import std.path : buildPath, dirName;
import std.stdio;

import amp.parser;
import amp.output.html;

/++
    Launches AMP in command-line mode
 +/
int runCLI(string[] args)
{
    bool optPrintVersionInfo;
    string optOutputDirectory;
    string optTemplateDirectory;

    // dfmt off
    GetoptResult rgetopt = getopt(
        args,
        config.passThrough,
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
        stderr.writeln("Error: No blueprint path specified");
        return 1;
    }

    // Output directory specified?
    if (args.length < 3)
    {
        // no
        stderr.writeln("Error: No output directory specified");
        return 1;
    }

    string path = args[$-2];
    string output = args[$-1];

    // Verify path
    if (!exists(path))
    {
        stderr.writeln("Error: Non-existant blueprint path (" ~ path ~ ")");
        return 1;
    }

    // Check output directory
    if (!exists(output))
    {
        mkdirRecurse(output);
    }
    else if (!isDir(output))
    {
        stderr.writeln("Error: The specified output directory is not a directory (" ~ output ~ ")");
        return 1;
    }

    if (optTemplateDirectory is null)
    {
        optTemplateDirectory = buildPath(dirName(thisExePath), "factory-templates");
    }

    // Determine path type (dir or file)
    if (isDir(path))
    {
        // Directory
        assert(0, "Not implemented");
    }
    else
    {
        // File
        ParserResult r = parseBlueprint(path);
        renderParserResult(r, "source/html_template");
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

