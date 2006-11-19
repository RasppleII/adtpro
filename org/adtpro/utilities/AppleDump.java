/*
 * ADTPro - Apple Disk Transfer ProDOS
 * Copyright (C) 2006 by David Schmidt
 * david__schmidt at users.sourceforge.net
 *
 * This program is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License as published by the 
 * Free Software Foundation; either version 2 of the License, or (at your 
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along 
 * with this program; if not, write to the Free Software Foundation, Inc., 
 * 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

package org.adtpro.utilities;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.PrintStream;

import org.apache.tools.ant.BuildException;
import org.apache.tools.ant.Task;

public class AppleDump extends Task
{

  public void execute() throws BuildException
  {
    String[] args = {
        "-infilename",_inFileName,
        "-outfilename",_outFileName,
        "-applename",_appleName,
        "-startaddrhex",_startAddrHex,
        "-numbyteswide",_numBytesString};
    if (checkArgs(args) == true)
    {
    int datum;
    boolean printedPrefix = false;
    int fileLength = 0;
    try
    {
      FileReader fr = new FileReader(_inFileName);
      PrintStream ps;
      try
      {
        ps = new PrintStream(new FileOutputStream(_outFileName));
      }
      catch (FileNotFoundException io)
      {
        throw new BuildException(io);
      }
      ps.println("");
      ps.println("3D0G");
      ps.println("NEW");
      ps.println("CALL -151");
      while(fr.ready())
      {
        for (int i = 0; i < _numBytes; i++)
        {
          if (fr.ready())
          {
            datum = fr.read();
            if (i == 0)
            {
              if (!printedPrefix)
              {
                ps.print(_startAddrHex);
                printedPrefix = true;
              }
              ps.print(":");
            }
            ps.print(UnsignedByte.toString(UnsignedByte.loByte(datum)));
            fileLength ++;
            if (i + 1 < _numBytes)
            {
              ps.print(" ");
            }
          }
        }
        ps.println();
      }
      ps.println("BSAVE "+_appleName+",A$"+_startAddrHex+",L"+fileLength+",S6,D1");
    }
    catch (FileNotFoundException e)
    {
      throw new BuildException(e);
    }
    catch (IOException e)
    {
      throw new BuildException(e);
    }
    }
    else
    {
      throw new BuildException("All arguments must be provided.");
    }
  }

  public boolean checkArgs(String[] args)
  {
    boolean rc = false;
    if (args.length == 10)
    {
      if ((args[1] != null) && (args[3] != null) && (args[5] != null) && (args[7] != null) && (args[9] != null))
      {
        rc = true;
      }
    }
    return rc;
  }

  public void setInfilename(String filename)
  {
    _inFileName = filename;
  }

  public void setOutfilename(String filename)
  {
    _outFileName = filename;
  }

  public void setApplename(String applename)
  {
    _appleName = applename;
  }

  public void setStartaddrhex(String startaddrhex)
  {
    _startAddrHex = startaddrhex;
  }

  public void setNumbyteswide(String numbytesstring)
  {
    _numBytes = Integer.parseInt(numbytesstring);
  }

  String _inFileName = null;
  String _outFileName = null;
  String _appleName = null;
  String _startAddrHex = null;
  String _numBytesString = "32";
  int _numBytes = 32;
}