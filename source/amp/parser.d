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
 +/
module amp.parser;

import std.stdio : File;
import std.string;

/++
    Parsed blueprint
 +/
struct ParserResult
{
    /++
        Path to the parsed file
     +/
    string filePath;
}

/++
    Parses a blueprint file
 +/
ParserResult parseBlueprint(string filePath)
{
    auto r = ParserResult();
    r.filePath = filePath;

    auto f = File(filePath, "r");

    string line;
    while((line = f.readln()) !is null)
    {
        line = line.strip;
    }
    return r;
}
