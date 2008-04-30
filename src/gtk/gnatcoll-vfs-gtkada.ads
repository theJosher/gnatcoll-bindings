-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2007-2008, AdaCore           --
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

with Glib.Values;

--  This package provides utilities to encapsulate a virtual file
--  in a GValue.

package GNATCOLL.VFS.GtkAda is

   -------------
   -- Gvalues --
   -------------

   procedure Set_File (Value : in out Glib.Values.GValue; File : Virtual_File);
   --  Store File into Value
   --  Value must have been initialized (See Glib.Values.Init) with type
   --  given by Get_Virtual_File_Type, below.

   function Get_File (Value : Glib.Values.GValue) return Virtual_File;
   --  Retrieve the file stored in Value

   function Get_Virtual_File_Type return Glib.GType;
   --  Return the gtype to use for virtual files

end GNATCOLL.VFS.GtkAda;
