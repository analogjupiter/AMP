/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
 +/
module amp.parser;

import amp.jsonprocessor;
import amp.apiwrappers;

import std.algorithm.mutation : copy;
import std.conv : to;
import std.file : read, readText;
import std.json;
import std.process;
import std.stdio;
import std.array : split, appender;
import std.string;
import std.regex;
import std.typecons;
import core.stdc.stdlib;

/++
    Parsed API def
 +/
struct ParserResult
{
    /++
        Path to the parsed file
     +/
    string filePath;

    APIRoot api;

    void opOpAssign(string op : "~")(ParserResult r2)
    {
        this.api ~= r2.api;
    }
}

class BlueprintParser
{
    private:
        string blueprint;
        DrafterLogger logger;
        Tuple!(string, ulong)[] apibFileLengths;

    public this(string blueprint, File logger, Tuple!(string, ulong)[] apibFileLengths)
    {
        this.blueprint = blueprint;
        this.logger = new DrafterLogger(logger, apibFileLengths);
        this.apibFileLengths = apibFileLengths;
    }

    public ParserResult parse()
    {
        JSONValue json = parseBlueprintToJson();
        auto r = ParserResult();

        try {
            r.filePath = "deprecated";
            r.api = process(json);
        } catch (JSONException ex) {
            writeln("Parsing Blueprint failed. Check the logs for errors.");
            exit(1);
        }

        return r;
    }

    private JSONValue parseBlueprintToJson()
    {
        ProcessPipes pipes = pipeProcess(["drafter", "-u", "-f",  "json"], Redirect.all);

        pipes.stdin.write(blueprint);
        pipes.stdin.flush();
        pipes.stdin.close();
        scope(exit) wait(pipes.pid);

        //TODO implement dynamic buffer size
        char[] jsonText = new char[1000000];
        jsonText = pipes.stdout.rawRead(jsonText);

        logger.writeStream(pipes.stderr);

        auto json = parseJSON(jsonText);

        if(json.isNull()) {
            writeln("Parsing Blueprint failed. Check the logs for errors.");
            exit(1);
        }

       return json;
    }
}

/++
Fixes the line numbers in errors of drafter's log and writes them to the given file
+/
class DrafterLogger
{
    private File logger;
    /+
    string ... file name
    ulong ... number of lines in the file
    +/
    private Tuple!(string, ulong)[] blueprintFileDetails;

    this(File logger, Tuple!(string, ulong)[] blueprintFileDetails)
    {
        this.logger = logger;
        this.blueprintFileDetails = blueprintFileDetails;
    }

    public void writeStream(File stream)
    {
        while(!stream.eof)
            this.writeln(stream.readln());

        logger.flush();
    }

    public void writeText(string errorText)
    {
        string[] errors = splitLines(errorText);

        foreach(string error; errors)
        {
            this.writeln(error);
        }
    }

    public void writeln(string errorLine)
    {
        auto match = matchFirst(errorLine, r" line (\d+), column (\d+) - line (\d+), column (\d+)".regex);
        if(!match.empty)
        {
            auto fixedError = appender!string;
            fixedError ~= match.pre;
            fixedError ~= "\n\t\tstart: ";
            fixedError ~= getCorrectErrorPosition(match[1].to!int, match[2].to!int);
            fixedError ~= "\n\t\tend: ";
            fixedError ~= getCorrectErrorPosition(match[3].to!int, match[4].to!int);

            logger.writeln(fixedError.data);
        } else {
            // print raw error
            logger.writeln(errorLine);
        }
    }

    private string getCorrectErrorPosition(int originalLineNumber, int columnNumber)
    {
        ulong nrOfLines = 0;
        foreach(Tuple!(string, ulong) file; blueprintFileDetails)
        {
            if(nrOfLines + file[1] > originalLineNumber)
            {
                int relativeLineNumber = originalLineNumber - nrOfLines.to!int;
                return format!"file %s, line %s, column %s"(file[0], relativeLineNumber, columnNumber);
            }
            nrOfLines += file[1];
        }
        return "";
    }
}

/++
    Parses a blueprint string
 +/
ParserResult parseBlueprint(string blueprint, File drafterLog, Tuple!(string, ulong)[]apibFileLengths)
{
    auto r = ParserResult();
    r.filePath = "deprecated";

    ProcessPipes pipes = pipeProcess(["drafter", "-u", "-f",  "json"], Redirect.all);

    pipes.stdin.write(blueprint);
    pipes.stdin.flush();
    pipes.stdin.close();
    scope(exit) wait(pipes.pid);

    //TODO implement dynamic buffer size
    char[] jsonText = new char[1000000];
    jsonText = pipes.stdout.rawRead(jsonText);

    while(!pipes.stderr.eof)
        writeDrafterErrorLog(drafterLog, pipes.stderr.readln(), apibFileLengths);

    JSONValue json = parseJSON(jsonText);
    r.api = process(json);

    return r;
}

void writeDrafterErrorLog(File drafterLog, string errorText, Tuple!(string, ulong)[] apibFileLengths)
{
    string[] errors = splitLines(errorText);

    foreach(string error; errors)
    {
        auto match = matchFirst(error, r" line (\d+), column (\d+) - line (\d+), column (\d+)".regex);
        if(!match.empty)
        {
            auto fixedError = appender!string;
            fixedError ~= match.pre;
            fixedError ~= "\n\t\tstart: ";
            fixedError ~= getCorrectedLine(apibFileLengths, match[1].to!int, match[2].to!int);
            fixedError ~= "\n\t\tend: ";
            fixedError ~= getCorrectedLine(apibFileLengths, match[3].to!int, match[4].to!int);

            drafterLog.writeln(fixedError.data);
        }
    }

}

string getCorrectedLine( Tuple!(string, ulong)[] apibFileLengths, int line, int column)
{
    ulong totalLength = 0;
    foreach(Tuple!(string, ulong) file; apibFileLengths)
    {
        if(totalLength + file[1] > line)
        {
            int relativeLineNumber = line - totalLength.to!int;
            return format!"file %s, line %s, column %s"(file[0], relativeLineNumber, column);
        }
        totalLength += file[1];
    }
    return "";
}
