-----------------------------------------------------------------------
--                          G N A T C O L L                          --
--                                                                   --
--                 Copyright (C) 2003-2008, AdaCore                  --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

--  This package abstracts file operations and names.
--  It is a layer on top of GNATCOLL.Filesystem, which allows you to use the
--  same code to manipulate (copy, rename, delete,...) files, independent of
--  the actual system you are running on (or even if the files happen to be on
--  a remote host).
--  This package provides additional abstraction with regards to file names.
--  Depending on the context, your application will sometime need to use base
--  names (no directory), or full name to reference a file. It is not always
--  clear from the API which type of name is expected, and this package allows
--  you to pass a Virtual_File instead, from which you can extract either the
--  base name or the full name, as needed. This package also abstracts whether
--  file names are case-sensitive or not (in fact, all systems can be
--  considered as case sensitive because file names should be displayed with
--  the exact casing that the user has chosen -- but in some cases the files
--  can be referenced through multiple casing).
--  It also takes care of reference counting, and will therefore free memory as
--  appropriate when it is no longer needed. That makes the type relatively
--  light weight, all the more because most of the information is computed only
--  when needed, and cached in some cases.
--  There is however a cost associated with Virtual_File: they are controlled
--  types, and as such generate a lot of extra code; and they require at least
--  one memory allocation when the file is created to store the name.

with Ada.Calendar;
with Ada.Finalization;
with Ada.Containers;
with GNAT.OS_Lib;
with GNAT.Strings;
with GNATCOLL.Filesystem;

package GNATCOLL.VFS is

   VFS_Directory_Error : exception;

   type Virtual_File is tagged private;
   No_File        : constant Virtual_File;

   type Virtual_File_Access is access constant Virtual_File;

   ----------------------------
   --  Creating Virtual_File --
   ----------------------------
   --  The following subprograms are used to create instances of Virtual_File.
   --  On the disk, a filename is typically just a series of bytes, with no
   --  special interpretation in utf8, iso-8859-1 or other pagesets (on most
   --  systems, windows always uses utf8 these days but has other
   --  specificities).
   --  As a result, a filename passed to these Create subprograms will not be
   --  interpreted through an encoding or another, but will just be stored as
   --  is. However, when comes the time to display the file on the disk, the
   --  filename needs to be converted to a known encoding, generally utf8.
   --  See the "Retrieving names" section below.

   function Create (Full_Filename : String) return Virtual_File;
   --  Return a file, given its full filename.
   --  The latter can be found, for source files, through the functions in
   --  projects-registry.ads.

   function Create
     (FS            : GNATCOLL.Filesystem.Filesystem_Access;
      Full_Filename : String) return Virtual_File;
   --  Return a file, given its full filename and an instance of a file
   --  system. The filesystem can possibly be running on a remote host, in
   --  which case the file will also be hosted on that machine.
   --  FS must not be freed while the file exists, since no copy is made

   function Create_From_Dir
     (Dir       : Virtual_File;
      Base_Name : String) return Virtual_File;
   --  Creates a file from its directory and base name

   function Create_From_Base (Base_Name : String) return Virtual_File;
   --  Return a file, given its base name.
   --  The full name will never be computable. Consider using Projects.Create
   --  if you know to which project the file belongs. Also consider using
   --  GPS.Kernel.Create
   --  ??? Currently, this does the same thing as create, but it is
   --  preferable to distinguish both cases just in case.

   ----------------------
   -- Retrieving names --
   ----------------------
   --  As mentioned above, a filename is stored internally as a series of bytes
   --  and not interpreted in anyway for an encoding. However, when you
   --  retrieve the name of a file for display, you will have to convert it to
   --  a known encoding.
   --  There are two sets of functions for retrieving names: Display_* will
   --  return the name converted through the Locale_To_Display function of the
   --  filesystem.
   --  All other functions will return the name as passed to the Create
   --  functions above, and therefore make no guarantee on the encoding of the
   --  file name.

   type Cst_String_Access is access constant String;

   function Base_Name
     (File : Virtual_File; Suffix : String := "") return String;
   --  Return the base name of the file

   function Base_Dir_Name (File : Virtual_File) return String;
   --  Return the base name of the directory or the file

   function Full_Name
     (File : Virtual_File; Normalize : Boolean := False)
      return Cst_String_Access;
   --  Return the full path to File.
   --  If Normalize is True, the file name is first normalized, note that links
   --  are not resolved there.
   --  The returned value can be used to recreate a Virtual_File instance.
   --  If file names are case insensitive, the normalized name will always
   --  be all lower cases.

   function Full_Name_Hash
     (Key : Virtual_File) return Ada.Containers.Hash_Type;
   --  Return a Hash_Type computed from the full name of the given VFS.
   --  Could be used to instantiate an Ada 2005 container that uses a VFS as
   --  key and requires a hash function.

   function File_Extension (File : Virtual_File) return String;
   --  Return the extension of the file, or the empty string if there is no
   --  extension. This extension includes the last dot and all the following
   --  characters.

   function Dir_Name (File : Virtual_File) return Cst_String_Access;
   --  Return the directory name for File. This includes any available
   --  on the protocol, so that relative files names are properly found.

   function Display_Full_Name (File : Virtual_File) return String;
   --  Same as Full_Name

   function Display_Base_Name (File : Virtual_File) return String;
   --  Same as Base_Name

   function Display_Dir_Name (File : Virtual_File) return String;
   --  Same as Dir_Name

   ------------------------
   -- Getting attributes --
   ------------------------

   function Get_Filesystem
     (File : Virtual_File) return GNATCOLL.Filesystem.Filesystem_Access;
   --  Return the filesystem for File

   function Is_Regular_File (File : Virtual_File) return Boolean;
   --  Whether File corresponds to an actual file on the disk.
   --  This also works for remote files.

   function "=" (File1, File2 : Virtual_File) return Boolean;
   --  Overloading of the standard operator

   function "<" (File1, File2 : Virtual_File) return Boolean;
   --  Compare two files, possibly case insensitively on file systems that
   --  require this.

   function Is_Parent (Parent, Child : Virtual_File) return Boolean;
   --  Compare Parent and Child directory and determines if Parent contains
   --  Child directory

   function Is_Writable (File : Virtual_File) return Boolean;
   --  Return True if File is writable

   function Is_Directory (VF : Virtual_File) return Boolean;
   --  Return True if File is in fact a directory

   function Is_Symbolic_Link (File : Virtual_File) return Boolean;
   --  Return True if File is a symbolic link

   function Is_Absolute_Path (File : Virtual_File) return Boolean;
   --  Return True if File contains an absolute path name, False if it only
   --  contains the base name or a relative name.

   procedure Set_Writable (File : VFS.Virtual_File; Writable : Boolean);
   --  If Writable is True, make File writable, otherwise make File unwritable

   procedure Set_Readable (File : VFS.Virtual_File; Readable : Boolean);
   --  If Readable is True, make File readable, otherwise make File unreadable

   function File_Time_Stamp (File : Virtual_File) return Ada.Calendar.Time;
   --  Return the timestamp for this file. This is GMT time, not local time.
   --  Note: we do not return GNAT.OS_Lib.OS_Time, since the latter cannot be
   --  created by anyone, and is just a private type.
   --  If the file doesn't exist, No_Time is returned.

   --------------------
   -- Array of files --
   --------------------

   type File_Array is array (Positive range <>) of Virtual_File;
   type File_Array_Access is access all File_Array;
   procedure Unchecked_Free (Arr : in out File_Array_Access);

   Empty_File_Array : constant File_Array;

   procedure Sort (Files : in out File_Array);
   --  Sort the array of files, in the order given by the full names

   -------------------------
   --  Manipulating files --
   -------------------------

   procedure Rename
     (File      : Virtual_File;
      Full_Name : String;
      Success   : out Boolean);
   --  Rename a file or directory. This does not work for remote files

   procedure Copy
     (File        : Virtual_File;
      Target_Name : String;
      Success     : out Boolean);
   --  Copy a file or directory. This does not work for remote files

   procedure Delete (File : Virtual_File; Success : out Boolean);
   --  Remove file from the disk. This also works for remote files

   function Read_File (File : Virtual_File) return GNAT.Strings.String_Access;
   --  Return the contents of an entire file, encoded with the locale encoding.
   --  If the file cannot be found, return null.
   --  The caller is responsible for freeing the returned memory.
   --  This works transparently for remote files

   --------------------------
   -- Directory operations --
   --------------------------

   Local_Root_Dir : constant Virtual_File;

   function Dir (File : Virtual_File) return Virtual_File;
   --  Return the virtual file corresponding to the directory of the file

   function Get_Current_Dir return Virtual_File;

   procedure Ensure_Directory (Dir : Virtual_File);
   --  Ensures that the file is a directory: add directory separator if
   --  needed.

   function Get_Root (File : Virtual_File) return Virtual_File;
   --  returns root directory of the file

   function Get_Parent (Dir : Virtual_File) return Virtual_File;
   --  return the parent directory if it exists, else No_File is returned

   function Sub_Dir (Dir : Virtual_File; Name : String) return Virtual_File;
   --  returns sub directory Name if it exists, else No_File is returned

   procedure Change_Dir (Dir : Virtual_File);
   --  Changes working directory. Raises Directory_Error if Dir_Name does not
   --  exist or is not a readable directory

   procedure Make_Dir (Dir : Virtual_File);
   --  Create a new directory named Dir_Name. Raises Directory_Error if
   --  Dir_Name cannot be created.

   type Read_Dir_Filter is (All_Files, Dirs_Only, Files_Only);

   function Read_Dir
     (Dir    : Virtual_File;
      Filter : Read_Dir_Filter := All_Files) return File_Array_Access;
   --  Reads all entries from the directory and returns a File_Array containing
   --  those entries, according to filter. The list of files returned
   --  includes directories in systems providing a hierarchical directory
   --  structure, including . (the current directory) and .. (the parent
   --  directory) in systems providing these entries.

   type Virtual_Dir is private;

   Invalid_Dir : constant Virtual_Dir;

   function Open_Dir (Dir : Virtual_File) return Virtual_Dir;
   --  Opens for reading a file

   procedure Read (VDir : in out Virtual_Dir; File : out Virtual_File);
   --  Returns next file or No_File is no file is left for current directory

   procedure Close (VDir : in out Virtual_Dir);
   --  Closes the Virtual_Dir

   -------------------
   -- Writing files --
   -------------------
   --  Writing is more complex than reading, since generally the whole buffer
   --  to write down is not available immediately, but the user wants to be
   --  able to write characters in a series of calls.
   --  The interface in this package will also support remote files. In this
   --  case, writing the small chunks is done in a temporary file, which is
   --  sent to the remote host only when the file is closed.

   type Writable_File is private;

   Invalid_File : constant Writable_File;
   --  Used when a file couldn't be open

   function Write_File
     (File   : Virtual_File;
      Append : Boolean := False) return Writable_File;
   --  Open File for writing. The returned handler can be used for writting.
   --  You must close it, otherwise the file will not actually be written in
   --  some cases. If Append is True then writting will be done at the end of
   --  the file if the file exists otherwise the file is created.
   --  Return Invalid_File is the file couldn't be open for writing

   procedure Write
     (File : in out Writable_File;
      Str  : String);
   --  Write a string to File. The contents of Str are written as-is

   procedure Close (File : in out Writable_File);
   --  Closes File, and write the file to disk.
   --  Use_Error is raised if the file could not be saved.

private
   --  This type is implemented as a controlled type, to ease the memory
   --  management (so that we can have gtk+ callbacks that take a Virtual
   --  File in argument, without caring who has to free the memory).
   --  Other solutions (using Name_Id to store the strings for instance) do
   --  not work properly, since the functions above cannot modify File
   --  itself, although they do compute some information lazily).

   type File_Type is
     (Unknown,
      --  File is not determined
      File,
      --  Regular file
      Directory
      --  Directory
      );

   type Contents_Record is record
      FS              : GNATCOLL.Filesystem.Filesystem_Access;
      Ref_Count       : Natural := 1;
      Full_Name       : GNAT.Strings.String_Access;
      Normalized_Full : GNAT.Strings.String_Access;
      Dir_Name        : GNAT.Strings.String_Access;
      Kind            : File_Type := Unknown;
   end record;
   type Contents_Access is access Contents_Record;

   type Virtual_File is new Ada.Finalization.Controlled with record
      Value : Contents_Access;
   end record;

   pragma Finalize_Storage_Only (Virtual_File);
   procedure Finalize (File : in out Virtual_File);
   procedure Adjust (File : in out Virtual_File);

   type Writable_File is record
      File     : Virtual_File;
      FD       : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Filename : GNAT.Strings.String_Access;
      Append   : Boolean;
   end record;

   Invalid_File : constant Writable_File :=
     ((Ada.Finalization.Controlled with Value => null),
      GNAT.OS_Lib.Invalid_FD, null, False);

   type Virtual_Dir is record
      File       : Virtual_File;
      Files_List : File_Array_Access;
      Current    : Natural;
   end record;

   Local_Root_Dir : constant Virtual_File :=
     (Ada.Finalization.Controlled with Value => new Contents_Record'(
        FS              => GNATCOLL.Filesystem.Get_Local_Filesystem,
        Ref_Count       => 1,
        Full_Name       => new String'(1 => GNAT.OS_Lib.Directory_Separator),
        Normalized_Full => new String'(1 => GNAT.OS_Lib.Directory_Separator),
        Dir_Name        => new String'(1 => GNAT.OS_Lib.Directory_Separator),
        Kind            => Directory));

   No_File : constant Virtual_File :=
     (Ada.Finalization.Controlled with Value => null);

   Empty_File_Array : constant File_Array :=
                        File_Array'(1 .. 0 => No_File);

   Invalid_Dir : constant Virtual_Dir :=
     ((Ada.Finalization.Controlled with Value => null),
      null,
      0);

   procedure Finalize (Value : in out Contents_Access);
   --  Internal version of Finalize

end GNATCOLL.VFS;
