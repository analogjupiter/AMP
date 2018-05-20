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
module amp.output.html;

import std.array : appender;
import std.path : buildPath;
import std.stdio : File;

import amp.apiwrappers;
import amp.parser;
import amp.output.generic;
import mustache;

/++
    Filenames of the templates used by HTMLAMPOutput
 +/
enum TemplateFileNames : string
{
    index = "index",
    group = "group"
}

enum HtmlExt = "html";
enum DotHtmlExt = '.' ~ HtmlExt;

class HTMLAPIDocsOutput : APIDocsOutput
{
final @safe:

    private
    {
        alias Mustache = MustacheEngine!string;

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
                this._mustache.path = value;
            }
        }
    }

    /++
        ctor
     +/
    public this(string templatePath)
    {
        this._mustache.path = templatePath;
    }

    public @system
    {
        /++
            Converts the API def to HTML and saves it on disk
         +/
        void write(ParserResult pr, string targetDirectory)
        {
            auto ctxIndex = new Mustache.Context;

            foreach(group; pr.api.groups)
            {
                this.writeGroup(group, targetDirectory);
            }
        }

        void writeGroup(Group group, string targetDirectory)
        {
            auto ctxGroup = new Mustache.Context;

            auto f = File(buildPath(targetDirectory, group.title ~ DotHtmlExt), "w");
            scope(exit) f.close();

            f.rawWrite(this._mustache.render(TemplateFileNames.group, ctxGroup));
        }
    }
}

