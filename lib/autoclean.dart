// Copyright (c) 2016, Ulrich Alt. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'dart:io';
import 'dart:collection';
import 'dart:async';

/// Holds info about a name and date of a directory
class DirectoryInfo {
  /// The patch name
  Directory thePath;

  /// Total size of contents
  int size;

  /// Reference date as stated in path
  DateTime refDate;

  /// should this be deleted ?
  bool toDelete;

  /// Build new DirectoryInfo from a path
  DirectoryInfo(this.thePath) {
    size = 0;
    toDelete = false;
    refDate = new DateTime(
        2000 +
            int.parse(thePath.path
                .substring(thePath.path.length - 6, thePath.path.length - 4)),
        int.parse(thePath.path
            .substring(thePath.path.length - 4, thePath.path.length - 2)),
        int.parse(thePath.path.substring(thePath.path.length - 2)));
  }

  /// add 'newSize' bytes to the total size
  void addSize(int newSize) {
    size += newSize;
  }
}

/// The worker class of the AutoCleaner
class AutoCleaner {
  Directory _thePath;
  int _maxSize;
  bool _simulate;
  HashMap<String, DirectoryInfo> _dirList;
  final RegExp _dirMatcher = new RegExp(r"\\1\d{5}$");
  final RegExp _fullDirMatcher = new RegExp(r"^(.+\\1\d{5})");

  /// Build new Autocleaner
  AutoCleaner.fromArgs(List<String> args) {
    ArgParser parser = new ArgParser();
    parser.addOption('path', abbr: 'p', help: 'Path to clean');
    parser.addFlag('simulate', abbr: 's', help: 'Simulate only');
    parser.addOption('maxSize', abbr: 'm', help: 'Maximum size allowed in GB');
    if (args.length < 3) {
      print(parser.usage);
    } else {
      ArgResults result = parser.parse(args);
      _thePath = new Directory(result["path"]);
      _maxSize = int.parse(result["maxSize"]) * 1024 * 1024 * 1024;
      _simulate = result["simulate"];
      _collectInfo();
    }
  }

  void _onEntity(FileSystemEntity ent) {
    if (ent is Directory && _dirMatcher.hasMatch(ent.path)) {
      _dirList.putIfAbsent(ent.path, () => new DirectoryInfo(ent));
    }
    if (ent is File) {
      Match dirName = _fullDirMatcher.firstMatch(ent.path);
      if (dirName != null) if (_dirList.containsKey(dirName.group(0)))
        ent.stat().then(
            (FileStat stat) => _dirList[dirName.group(0)].addSize(stat.size));
    }
  }

  void _goOn() {
    List<DirectoryInfo> sortedDirs = _dirList.values.toList();
    sortedDirs.sort(
        (DirectoryInfo a, DirectoryInfo b) => a.refDate.compareTo(b.refDate));
    int totalSize =
        sortedDirs.fold(0, (int size, DirectoryInfo elem) => size += elem.size);
    int i = 0;
    while (totalSize > _maxSize && i < sortedDirs.length) {
      sortedDirs[i].toDelete = true;
      i++;
      totalSize -= sortedDirs[i].size;
    }
    if (_simulate)
      sortedDirs.forEach((DirectoryInfo dir) =>
          print("${dir.thePath} ${dir.size} ${dir.refDate} ${dir.toDelete}"));
    else
      sortedDirs.where((DirectoryInfo dir) => dir.toDelete).forEach(
          (DirectoryInfo dir) => dir.thePath.deleteSync(recursive: true));
  }

  void _collectInfo() {
    if (!_thePath.existsSync()) {
      print("Directory $_thePath does not exist.");
    } else {
      _dirList = new HashMap<String, DirectoryInfo>();
      Stream<FileSystemEntity> stream = _thePath.list(recursive: true);
      stream.listen(_onEntity, onDone: _goOn);
    }
  }
}
