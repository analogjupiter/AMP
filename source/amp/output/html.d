/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
 +/
module amp.output.html;

import std.array : appender;
import std.path : buildPath;
import std.stdio : File;
import std.string;
import amp.apiwrappers;
import amp.parser;
import amp.output.generic;
import amp.output.mustachecontextbuilder;
import mustache;

enum TemplateFileName = "amp";
enum TemplateFileExt = Mustache.Option().ext;
enum TemplateFileNameFull = TemplateFileName ~ '.' ~ TemplateFileExt;

private
{
    alias Mustache = MustacheEngine!string;
}

/++
    Mustache template based HTML output
 +/
class HTMLAPIDocsOutput : APIDocsOutput
{
final @safe:

    private
    {
        Mustache _mustache;
    }

    public
    {
        @property
        {
            /++
                Mustache instance used by the HTML outputter
             +/
            Mustache mustache()
            {
                return this._mustache;
            }
        }

        @property
        {
            /++
                Template directory to use
             +/
            string templatePath()
            {
                return this._mustache.path;
            }

            /++ ditto +/
            void templatePath(string value)
            {
                this._mustache.ext = TemplateFileExt;
                this._mustache.path = value;
            }
        }
    }

    /++
        ctor
     +/
    public this(string templatePath)
    {
        this._mustache.level = Mustache.CacheLevel.no;
        this._mustache.path = templatePath;
    }

    public @system
    {
        /++
            Converts the API def to HTML
         +/
        void write(ParserResult pr, File target)
        {
            auto contextBuilder = new MustacheContextBuilder();
            target.rawWrite(mustache.render(TemplateFileName, contextBuilder.getContext(pr.api)));
        }
    }
}
