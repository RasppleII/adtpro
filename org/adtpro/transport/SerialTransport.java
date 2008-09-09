/*
 * ADTPro - Apple Disk Transfer ProDOS
 * Copyright (C) 2006 by David Schmidt
 * david__schmidt at users.sourceforge.net
 *
 * Serial Transport notions derived from the jSyncManager project
 * http://jsyncmanager.sourceforge.net/
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

package org.adtpro.transport;

import java.io.*;
import java.util.*;

import org.adtpro.resources.Messages;
import org.adtpro.utilities.Log;

import gnu.io.*;

public class SerialTransport extends ATransport
{
  protected CommPortIdentifier portId;

  protected RXTXPort port;

  protected DataInputStream inputStream;

  protected DataOutputStream outputStream;

  protected boolean connected;

  protected String _portName = null;

  protected int _currentSpeed = 0;

  protected boolean _hardware = false;

  /**
   * Create a new instance of the Comm API Transport. This constructor creates a
   * new instance of the Comm API Transport.
   * 
   * @param portName
   *          A string representing the Comm Port to be used.
   * @param speed
   * @throws NoSuchPortException
   * @throws PortInUseException
   * @throws UnsupportedCommOperationException
   * @throws IOException
   * @exception Exception
   *              used to pass any exceptions thrown during initialization.
   */

  public SerialTransport(String portName, String speed, boolean hardware) throws Exception
  {
    Log.getSingleton();
    Log.println(false, "SerialTransport constructor entry.");
    this._portName = portName;
    connected = false;
    _hardware = hardware;
    _currentSpeed = Integer.parseInt(speed);
    Log.println(false, "SerialTransport constructor exit.");
  }

  public int transportType()
  {
    return TRANSPORT_TYPE_SERIAL;
  }

  /**
   * Closes the Java COMM API port.
   * 
   * @exception Exception
   *              any exception encountered is rethrown.
   */

  public synchronized void close() throws Exception
  {
    if (connected)
    {
      connected = false;
      Log.println(false, "SerialTransport.close() closing port..."); //$NON-NLS-1$
      port.close();
      Log.println(false, "SerialTransport.close() closed port."); //$NON-NLS-1$
      Log.println(true, "SerialTransport closed port."); //$NON-NLS-1$
    }
    else
      Log.println(false, "SerialTransport.close() didn't think port was connected."); //$NON-NLS-1$
  }

  /**
   * Flushes the input buffer of any remaining data.
   * 
   * @exception IOException
   *              thrown when a problem occurs with flushing the stream.
   */

  public void flush() throws IOException
  {
    while (inputStream.available() > 0)
    {
      inputStream.read();
    }
  }

  /**
   * Returns an array of Strings representing the names of available ports. This
   * method will return to the caller an array of strings representing the
   * serial ports available on this system.
   * 
   * @return an array of String representing the names of the available ports.
   */

  public static String[] getPortNames()
  {
    Vector v = new Vector();
    Enumeration enumeration = null;

    try
    {
      enumeration = CommPortIdentifier.getPortIdentifiers();
    }
    catch (java.lang.NoClassDefFoundError ex)
    {
      Log.println(true, Messages.getString("SerialTransport.2")); //$NON-NLS-1$
      return null;
    }

    while (enumeration.hasMoreElements())
    {
      v.addElement(((CommPortIdentifier) enumeration.nextElement()).getName());
    }

    String ret[] = new String[v.size()];
    for (int j = 0; j < v.size(); j++)
      ret[j] = (String) v.elementAt(j);
    return ret;
  }

  /**
   * Opens a read/write connection to the implemented transport. This method
   * should open the transport device being implemented using default
   * parameters.
   * 
   * @exception IOException
   *              thrown when a problem occurs opening the stream.
   */

  public void open() throws Exception
  {
    if (connected)
    {
      return;
    }
    else
    {
      open(_portName, _currentSpeed, _hardware);
    }
  }

  /**
   * Opens a read/write connection to the implemented transport. This method
   * should open the transport device being implemented using default
   * parameters.
   * 
   * @exception IOException
   *              thrown when a problem occurs with opening the stream.
   */
  public void open(String portName, int portSpeed, boolean hardware) throws Exception
  {
    Log.println(false, "SerialTransport.open() entry.");
    if (connected)
    {
      Log.println(false, "SerialTransport.open() was connected; closing.");
      close();
    }
    portId = CommPortIdentifier.getPortIdentifier(portName);
    port = (RXTXPort) portId.open(Messages.getString("SerialTransport.3"), 100); //$NON-NLS-1$
    port.setSerialPortParams(portSpeed, 8, 1, 0);
    setHardwareHandshaking(hardware);
    port.enableReceiveTimeout(250);
    inputStream = new DataInputStream(port.getInputStream());
    outputStream = new DataOutputStream(port.getOutputStream());
    connected = true;
    Log.println(true, "SerialTransport opened port named " + portName + " at speed " + portSpeed + "."); //$NON-NLS-1$ //$NON-NLS-2$ //$NON-NLS-3$
    return;
  }

  /**
   * Read a single byte from the Java COMM API port.
   * 
   * @throws IOException
   */

  public byte readByte(int seconds) throws TransportTimeoutException
  {
    int collectedTimeouts = 0;
    // Log.println(false, "SerialTransport.readByte() entry, timeout: " + seconds + " seconds.");
    boolean hasData = false;
    byte oneByte = 0;
    while ((hasData == false) && (connected))
    {
      try
      {
        oneByte = inputStream.readByte();
        hasData = true;
      }
      catch (java.io.IOException e)
      {
        collectedTimeouts++;
      }
      if (collectedTimeouts / 4 > seconds) throw new TransportTimeoutException();
    }
    /*
    if (hasData) Log.println(false, "SerialTransport.readByte() exit, byte: " + UnsignedByte.toString(oneByte));
    else
      Log.println(false, "SerialTransport.readByte() exit.");
      */
    return oneByte;
  }

  /**
   * Sets the parameters of the underlying Java COMM API port.
   * 
   * @param port
   *          The port to set the transport to.
   * @param speed
   *          The speed to set the transport to.
   * @param hardware
   *          Boolean to say if hardware handshaking should be used
   * @exception IOException
   *              thrown when a problem occurs with flushing the stream.
   */

  public void setParms(String newPort, int newSpeed, boolean newHardware) throws Exception
  {
    if (!newPort.equals(_portName))
    {
      close();
      open(newPort, newSpeed, newHardware);
      _portName = newPort;
    }
    else
    {
      setHardwareHandshaking(newHardware);
      if (_currentSpeed != newSpeed)
      {
        flush();
        _currentSpeed = newSpeed;
        port.setSerialPortParams(newSpeed, 8, 1, 0);
      }
    }
  }

  /**
   * Sets the speed of the underlying Java COMM API port.
   * 
   * @param speed
   *          The speed to set the transport to.
   * @exception IOException
   *              thrown when a problem occurs with flushing the stream.
   */

  public void setSpeed(int speed) throws Exception
  {
    if (_currentSpeed != speed)
    {
      flush();
      _currentSpeed = speed;
      port.setSerialPortParams(speed, 8, 1, 0);
    }
  }

  /**
   * Writes an array of bytes to the Java COMM API port.
   * 
   * @param data
   *          the bytes to be written to the serial port.
   */

  public void writeBytes(byte data[], String log)
  {
    try
    {
      /*
        Log.println(false, "SerialTransport.writeBytes() writing:");
        for (int i = 0; i < data.length; i++)
        {
          Log.println(false, UnsignedByte.toString(data[i]) + " ");
        }
       */
      /*
       * Problem: 300 baud garbles screen text while
       * doing a 'directory' listing because it writes lotsa
       * bytes at once as a stream.
       * Solution: send bytes one at a time if we're going
       * so slow; blast 'em otherwise.
       */
      if (_currentSpeed == 300)
      {
        for (int i = 0; i < data.length; i++)
          outputStream.write(data[i]);
      }
      else
        outputStream.write(data, 0, data.length);
    }
    catch (IOException ex)
    {
      Log.printStackTrace(ex);
    }
  }

  public void writeBytes(String str)
  {
    writeBytes(str.getBytes(), ""); //$NON-NLS-1$
  }

  public void writeBytes(byte[] data)
  {
    writeBytes(data, ""); //$NON-NLS-1$
  }

  public void writeBytes(char[] data)
  {
    byte[] bytes = new byte[data.length];
    for (int i = 0; i < data.length; i++)
      bytes[i] = (byte) data[i];
    writeBytes(bytes, ""); //$NON-NLS-1$
  }

  public void writeByte(char datum)
  {
    byte data[] =
    { (byte) (datum) };
    writeBytes(data, ""); //$NON-NLS-1$
  }

  public void writeByte(int datum)
  {
    byte data[] =
    { (byte) (datum & 0xff) };
    writeBytes(data, ""); //$NON-NLS-1$
  }

  public void writeByte(byte datum)
  {
    byte data[] =
    { datum };
    writeBytes(data, ""); //$NON-NLS-1$
  }

  public void writeByte(byte datum, String str)
  {
    byte data[] =
    { datum };
    writeBytes(data, str);
  }

  public void pullBuffer()
  {
  // Serial port is byte-by-byte, no buffering
  }

  public void pushBuffer()
  {
  // Serial port is byte-by-byte, no buffering
  }

  public void flushReceiveBuffer()
  {
  // Serial port is byte-by-byte, no buffering
  }

  public void flushSendBuffer()
  {
    try
    {
      outputStream.flush();
    }
    catch (IOException e)
    {
      Log.println(false,"SerialTransport.flushSendBuffer() failed to flush the stream.");
    }
  }

  public void setFullSpeed()
  {
    try
    {
      port.setSerialPortParams(_currentSpeed, 8, 1, 0);
    }
    catch (UnsupportedCommOperationException e)
    {
      Log.printStackTrace(e);
    }
  }

  public void setSlowSpeed(int speed)
  {
    Log.println(false, "SerialTransport.setSlowSpeed() setting speed to " + speed);
    try
    {
      port.setSerialPortParams(speed, 8, 1, 0);
    }
    catch (UnsupportedCommOperationException e)
    {
      Log.printStackTrace(e);
    }
  }

  public boolean supportsBootstrap()
  {
    return true;
  }

  public void pauseIncorrectCRC()
  {
  // Only necessary for audio transport
  }

  public void setHardwareHandshaking(boolean state)
  {
    _hardware = state;
    if (state) port.setFlowControlMode(SerialPort.FLOWCONTROL_NONE);
    else
      port.setFlowControlMode(SerialPort.FLOWCONTROL_RTSCTS_IN);
  }

  public String getInstructionsDone(String guiString)
  {
    Log.println(false,"SerialTransport.getInstructionsDone() getting instructions for: "+guiString);
    String ret = "";
    if (guiString.equals(Messages.getString("Gui.BS.ProDOS")))
    {
      ret = Messages.getString("Gui.BS.DumpProDOSInstructionsDone");
    }
    else
      if (guiString.equals(Messages.getString("Gui.BS.ProDOS2")))
      {
        ret = Messages.getString("Gui.BS.DumpProDOSInstructions2Done");
      }
      else
          if (guiString.equals(Messages.getString("Gui.BS.DOS")))
          {
            ret = Messages.getString("Gui.BS.DumpDOSInstructionsDone");
          }
          else
              if (guiString.equals(Messages.getString("Gui.BS.SOS")))
              {
                /* ret = Messages.getString("Gui.BS.DumpSOSInstructionsDone"); */
              }
    Log.println(false,"SerialTransport.getInstructionsDone() returning: "+ret);
    return ret;
  }

  public String getInstructions(String guiString, int fileSize, int speed)
  {
    String ret = "'SerialTransport.getInstructions() - returned null!'";
    if (guiString.equals(Messages.getString("Gui.BS.ProDOS"))) ret = Messages
        .getString("Gui.BS.DumpProDOSInstructions");
    else
      if (guiString.equals(Messages.getString("Gui.BS.ProDOS2"))) ret = Messages
          .getString("Gui.BS.DumpProDOSInstructions2");
      else
          if (guiString.equals(Messages.getString("Gui.BS.DOS"))) ret = Messages.getString("Gui.BS.DumpDOSInstructions");
          else
              if (guiString.equals(Messages.getString("Gui.BS.SOS"))) ret = Messages.getString("Gui.BS.DumpSOSInstructions");
        else
          if (guiString.equals(Messages.getString("Gui.BS.ADT"))) ret = Messages
              .getString("Gui.BS.DumpADTInstructions");
          else
            if (guiString.equals(Messages.getString("Gui.BS.ADTPro"))) ret = Messages
                .getString("Gui.BS.DumpProInstructions");
            else
              if (guiString.equals(Messages.getString("Gui.BS.ADTProAudio"))) ret = Messages
                  .getString("Gui.BS.DumpProAudioSerialInstructions");
              else
                if (guiString.equals(Messages.getString("Gui.BS.ADTProEthernet"))) ret = Messages
                    .getString("Gui.BS.DumpProEthernetInstructions");
    String baudCommand;
    switch (speed)
    {
      case 300:
        baudCommand = "6";
        break;
      case 600:
        baudCommand = "7";
        break;
      case 1200:
        baudCommand = "8";
        break;
      case 1800:
        baudCommand = "9";
        break;
      case 2400:
        baudCommand = "10";
        break;
      case 3600:
        baudCommand = "11";
        break;
      case 4800:
        baudCommand = "12";
        break;
      case 7200:
        baudCommand = "13";
        break;
      case 9600:
        baudCommand = "14";
        break;
      case 19200:
        baudCommand = "15";
        break;
      default:
        baudCommand = "6";
    }
    ret = ret.replaceFirst("%1%", baudCommand);

    Log.println(false, "SerialTransport.getInstructionsDone() returning:\n" + ret);
    return ret;
  }
}
