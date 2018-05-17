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
module amp.parser;

import amp.jsontreeprocessor;

import std.conv : to;
import std.file : read;
import std.json;
import std.process;
import std.stdio;


enum HTTPMethod{
    GET,
    POST,
    PATCH,
    PUT,
    DELETE
}

struct Attribute
{
    string name;
    string dataType;
    string description;
}

struct GetParameter
{
    string name;
    string dataType;
    string description;
    bool isRequired;
}

struct Request
{
    string jsonExample;
    string description;
}

struct Response
{
    string jsonExample;
    string description;

    int httpStatusCode;
}

struct Action
{
    string title;
    string description;
    HTTPMethod httpMethod;

    Request[] requests;
    Response[] responses;
    GetParameter[] getParameters;
    Attribute[] attributes;
}

struct Resource
{
    string title;
    string url;
    string description;

    Action[] actions;
    Attribute[] attributes;
}

struct Group
{
    string title;
    string description;

    Resource[] resources;
}

struct APIRoot
{
    string title;
    string description;

    Group[] groups;
}

/++
    Parsed blueprint
 +/
struct ParserResult
{
    /++
        Path to the parsed file
     +/
    string filePath;

    APIRoot api;
}

/++
    Parses a blueprint file
 +/
ParserResult parseBlueprint(string filePath)
{
    auto r = ParserResult();
    r.filePath = filePath;

    ProcessPipes pipes = pipeProcess(["drafter", "-f json"], Redirect.all, null, Config.suppressConsole);
    pipes.stdin.writeln(read(filePath));
    pipes.stdin.flush();
    pipes.stdin.close();
    wait(pipes.pid);


    //TODO implement dynamic buffer size
    char[] jsonText = new char[1000000];
    jsonText = pipes.stdout.rawRead(jsonText);

    char[] errorText = new char[1000000];
    errorText = pipes.stderr.rawRead(errorText);
    writeln(jsonText);
    JSONValue json = parseJSON(jsonText);

    auto api = parseRoot(json);
    writeln(api.to!(string));
    return r;
}

