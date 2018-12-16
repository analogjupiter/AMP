/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
 +/
module amp.settings;

import std.file : readText, copy, dirEntries, DirEntry, exists, isDir, mkdirRecurse, SpanMode, thisExePath;
import std.stdio;
import std.typecons;

class Settings
{
    protected static Settings _instance;

    public string projectName ="";// TODO

    public string templateDirPath;
    public string blueprintPath;

    public string outputDirPath;        // directory, where everything is outputted
    public string outputHtmlPath;       // path to the project.html file
    public File output;         // either stdout or file of outputHtmlPath

    public bool useStdout;      // results get printed to stdout instead of file
    public bool useStderr;
    public bool forceOverride;

    public File drafterLog;
    public Tuple!(string, ulong)[] blueprintFileDetails;

    public static Settings instance()
    {
        if(_instance is null)
            _instance = new Settings();

        return _instance;
    }

    protected this()
    {
    }
}
