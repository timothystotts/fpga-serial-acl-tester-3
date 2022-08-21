# -*- coding: utf-8 -*-
"""-----------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--------------------------------------------------------------------------------
-- @file display_pmod_parse_from_spi_spy.py
--
-- @brief A script to parse specific SPI bus control of the Pmod CLS and Pmod
-- SF3 as capturerd with digital logic analyzer. Parsing and testing specific
-- to both the Pmod interfaces as well as project fpga-serial-mem-tester-1 .
-----------------------------------------------------------------------------"""

import io
import sys
import re
import copy

class N25QCommand:
    def __init__(self, copi, cipo):
        self._copi = copi
        self._cipo = cipo
        self.lineFormat = 1
        self._copiFormatted = self._copi
        self._cipoFormatted = self._cipo

    def insertDashes(self, dashPos):
        self._copiFormatted = copy.copy(self._copi)
        self._cipoFormatted = copy.copy(self._cipo)
        
        for i in reversed(dashPos):
            self._copiFormatted.insert(i, '--')
            self._cipoFormatted.insert(i, '--')

    def __str__(self):
        if self.lineFormat == 2:
            return "N25Q 0x{1} {0:<30}\t(\nout: {2};\nin : {3})".format(
                self.CommandName, self.CommandByte,
                " ".join(self._copiFormatted),
                " ".join(self._cipoFormatted))
        else:
            return "N25Q 0x{1} {0:<30}\t(out: {2}; in: {3})".format(
                self.CommandName, self.CommandByte,
                " ".join(self._copiFormatted),
                " ".join(self._cipoFormatted))

    def _getAddrAsInt(self, first, length, arr):
        try:
            s = ""
            for i in range(first,first+length):
                s += arr[i]
            v = int(s, 16)
            return v
        except ValueError:
            return -1

    def _getFlashSequence(self, first, length, arr):
        try:
            v0 = int(arr[first + 0], 16)
            v1 = int(arr[first + 1], 16)
            diff = (v1 - v0) & 0xff
            total = 1
            
            for i in range(first+1, first+length):
                v0 = int(arr[i - 1], 16)
                v1 = int(arr[i], 16)
                if ((v1 - v0) & 0xff == diff):
                    total += 1
            
            return total
        except ValueError:
            return -1
        except IndexError:
            return -2
 
class N25QUnknown(N25QCommand):
    CommandByte = "xx"
    CommandName = "Unknown Command / Spy Fail"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)

class N25QWriteEnable(N25QCommand):
    CommandByte = "06"
    CommandName = "WriteEnable"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, ))
    
class N25QReadStatusRegister(N25QCommand):
    CommandByte = "05"
    CommandName = "ReadStatusRegister"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 2))
 
class N25QReadFlagStatusRegister(N25QCommand):
    CommandByte = "70"
    CommandName = "ReadFlagStatusRegister"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 2))
        
class N25QSectorErase(N25QCommand):
    CommandByte = "D8"
    CommandName = "SectorErase"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 4))

    def getEraseAddrAsInt(self):
        return self._getAddrAsInt(1, 3, self._copi)

class N25Q4ByteSubsectorErase(N25QCommand):
    CommandByte = "21"
    CommandName = "4ByteSubsectorErase"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 5))

    def getEraseAddrAsInt(self):
        return self._getAddrAsInt(1, 4, self._copi)

class N25QPageProgram(N25QCommand):
    CommandByte = "02"
    CommandName = "PageProgram"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 4, 4+256))
        self.lineFormat = 2

    def getProgAddrAsInt(self):
        return self._getAddrAsInt(1, 3, self._copi)
        
    def getProgSequence(self):
        return self._getFlashSequence(4, 256, self._copi)

class N25Q4BytePageProgram(N25QCommand):
    CommandByte = "12"
    CommandName = "4BytePageProgram"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 5, 5+256))
        self.lineFormat = 2

    def getProgAddrAsInt(self):
        return self._getAddrAsInt(1, 4, self._copi)

    def getProgSequence(self):
        return self._getFlashSequence(5, 256, self._copi)

class N25QRead(N25QCommand):
    CommandByte = "03"
    CommandName = "Read"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 4, 4+256))
        self.lineFormat = 2

    def getReadAddrAsInt(self):
        return self._getAddrAsInt(1, 3, self._copi)

    def getReadSequence(self):
        return self._getFlashSequence(4, 256, self._cipo)
        
class N25Q4ByteFastRead(N25QCommand):
    CommandByte = "0C"
    CommandName = "4ByteFastRead"
    
    def __init__(self, copi, cipo):
        super().__init__(copi, cipo)
        self.insertDashes((1, 5, 6, 6+256))
        self.lineFormat = 2
        
    def getReadAddrAsInt(self):
        return self._getAddrAsInt(1, 4, self._copi)
        
    def getReadSequence(self):
        return self._getFlashSequence(6, 256, self._cipo)

class N25QCommandFactory:
    def __init__(self):
        pass
    
    def getCmd(self, bCopi, bCipo):
        
        if (len(bCopi) > 0):
            b = bCopi[0]
            print(b)
            if (b == N25QWriteEnable.CommandByte):
                cmd = N25QWriteEnable(bCopi, bCipo)
            elif (b == N25QReadStatusRegister.CommandByte):
                cmd = N25QReadStatusRegister(bCopi, bCipo)
            elif (b == N25QSectorErase.CommandByte):
                cmd = N25QSectorErase(bCopi, bCipo)
            elif (b == N25QPageProgram.CommandByte):
                cmd = N25QPageProgram(bCopi, bCipo)
            elif (b == N25QRead.CommandByte):
                cmd = N25QRead(bCopi, bCipo)
            elif (b == N25QReadFlagStatusRegister.CommandByte):
                cmd = N25QReadFlagStatusRegister(bCopi, bCipo)
            elif (b == N25Q4ByteSubsectorErase.CommandByte):
                cmd = N25Q4ByteSubsectorErase(bCopi, bCipo)
            elif (b == N25Q4BytePageProgram.CommandByte):
                cmd = N25Q4BytePageProgram(bCopi, bCipo)
            elif (b == N25Q4ByteFastRead.CommandByte):
                cmd = N25Q4ByteFastRead(bCopi, bCipo)
            else:
                cmd = N25QUnknown(bCopi, bCipo)
        else:
        	print(None)
        	cmd = N25QUnknown(bCopi, bCipo)

        return cmd

class AnalogDiscoverySpiSpyParser:
    EscCharacters = ["1B",]
    PartsCopi = ["c", "cp"]
    PartsCipo = ["p", "cp"]
    rexData = re.compile(r"^Data[:][ ]")

    def __init__(self, fileName):
        self._currentLine = None
        self._ioParts = None
        self._fh = io.open(fileName, "r")
        self._strCopi = None
        self._strCipo = None
        self._asciiCopi = None
        self._asciiCipo = None
        self._flashCmds = []
        self._cmdFactory = N25QCommandFactory()
        
    def readCurrentLine(self):
        self._currentLine = self._fh.readline()
        if self._currentLine:
            return True
        else:
            return False
        
    def parseDataParts(self):
        if self._currentLine:
            if self.rexData.match(self._currentLine):
                dataParts = self._currentLine.split(":")
                lineParts = dataParts[1].split(",")
                self._ioParts = []
                for linePart in lineParts:
                    partRep = linePart.replace('h', '')
                    self._ioParts.append(partRep.split("|"))
                return True
            else:
                return False
        else:
            return False
    
    def close(self):
        self._fh.close()
        
    def getIoParts(self):
        return self._ioParts

    def getFlashCmds(self):
        return self._flashCmds

    def getIoPartsAsN25Q(self):
        bCopi = []
        bCipo = []

        for ioPart in self.getIoParts():
            if (len(ioPart) == 2):
                bCopi.append(ioPart[0].strip())
                bCipo.append(ioPart[1].strip())
        
        cmd = self._cmdFactory.getCmd(bCopi, bCipo)
        
        self._flashCmds.append(cmd)

        return str(cmd)

    def _genHexStrAndEsc(self, arr):
        strArr = ""
        escArr = []
        
        for a in arr:
            if (a not in self.EscCharacters):
                strArr += a
            else:
                escArr.append(len(strArr))

        return (strArr, escArr)

    def _genAsciiEsc(self, arr):
        (strArr, escArr) = self._genHexStrAndEsc(arr)
        asciiArr = ""
        
        ba = str(bytearray.fromhex(strArr).decode())
        for b in range(len(ba)):
            if (len(escArr) > 0):
                l = escArr[0]
                while(b == l):
                    escArr.pop(0)
                    asciiArr += r"\x"
                    if (len(escArr) > 0):
                        l = escArr[0]
                    else:
                        l = -1
                
            asciiArr += ba[b]
        
        return (strArr, asciiArr)

    def getIoPartsAsEscAscii(self):
        bCopi = []
        bCipo = []

        for ioPart in self.getIoParts():
            if (len(ioPart) == 2):
                bCopi.append(ioPart[0].strip())
                bCipo.append(ioPart[1].strip())
        
        (self._strCopi, self._asciiCopi) = self._genAsciiEsc(bCopi)
        (self._strCipo, self._asciiCipo) = self._genAsciiEsc(bCipo)
        
    def getCurrentLine(self):
        return self._currentLine
    
    def getStrCopi(self):
        return self._strCopi
    
    def getStrCipo(self):
        return self._strCipo
    
    def getAsciiCopi(self):
        return self._asciiCopi
    
    def getAsciiCipo(self):
        return self._asciiCipo
        
class PmodCLSTranslator:
    def __init__(self, partFlag, filename):
        self._partFlag = partFlag
        self._adssp = AnalogDiscoverySpiSpyParser(filename)
        self._fhParse = io.open(filename + "_parse.txt", "w")
    
    def parseWithAdssp(self):
        i = 0
        
        while(self._adssp.readCurrentLine()):
            i = i + 1
            if self._adssp.parseDataParts():            
                self._adssp.getIoPartsAsEscAscii()
                
                if (self._partFlag in self._adssp.PartsCopi):                
                    self._fhParse.write(self._adssp.getStrCopi())
                    self._fhParse.write("\n")
                    self._fhParse.write(self._adssp.getAsciiCopi())
                    self._fhParse.write("\n")
    
                if (self._partFlag in self._adssp.PartsCipo):
                    self._fhParse.write(self._adssp.getStrCipo())
                    self._fhParse.write("\n")
                    self._fhParse.write(self._adssp.getAsciiCipo())
                    self._fhParse.write("\n")
    
                self._fhParse.write("\n")
                
        self._adssp.close()
        self._fhParse.close()
        
class PmodSF3TesterValidator:
    def __init__(self, filename):
        self._adssp = AnalogDiscoverySpiSpyParser(filename)
        self._fhParse = io.open(filename + "_parse.txt", "w")
        self._fhCheck = io.open(filename + "_check.txt", "w")
        self._thisAddr = 0
        self._prevAddr = 0
        self._eraseIncr = 4096
        self._readIncr = 256
        self._progIncr = 256
        self._ssEraseIncr = self._progIncr * 16
        self._sEraseIncr = self._ssEraseIncr * 16
    
    def parseWithAdssp(self):
        i = 0
        while(self._adssp.readCurrentLine()):
            i = i + 1
            if self._adssp.parseDataParts():            
                s = self._adssp.getIoPartsAsN25Q()
                
                if s:
                    self._fhParse.write(s)
                    self._fhParse.write("\n")
    
                self._fhParse.write("\n")
                
        self._adssp.close()
        self._fhParse.close()
        
    def _checkEraseAddr(self, cmd):
        if (hasattr(cmd, 'getEraseAddrAsInt')):
            self._prevAddr = self._thisAddr
            self._thisAddr = cmd.getEraseAddrAsInt()
            self._diffAddr = self._thisAddr - self._prevAddr
            
            if (isinstance(cmd, N25QSectorErase)):
                self._eraseIncr = self._sEraseIncr
            else:
                self._eraseIncr = self._ssEraseIncr

            if (self._diffAddr == self._eraseIncr):
                print(f"N25Q{cmd.CommandName} Check: valid erase address"
                      f" increment by {self._diffAddr}", file=self._fhCheck)
            else:
                print(f"N25Q{cmd.CommandName} Check: invalid erase address"
                      f" increment by {self._diffAddr}", file=self._fhCheck)
        else:
            pass

    def _checkReadAddr(self, cmd):
        if (hasattr(cmd, 'getReadAddrAsInt')):
            self._prevAddr = self._thisAddr
            self._thisAddr = cmd.getReadAddrAsInt()
            self._diffAddr = self._thisAddr - self._prevAddr
            
            if (self._diffAddr == self._readIncr):
                print(f"N25Q{cmd.CommandName} Check: valid read address"
                      f" increment by {self._diffAddr}", file=self._fhCheck)
            else:
                print(f"N25Q{cmd.CommandName} Check: invalid read address"
                      f" increment by {self._diffAddr}", file=self._fhCheck)
        else:
            pass

    def _checkProgAddr(self, cmd):
        if (hasattr(cmd, 'getProgAddrAsInt')):
            self._prevAddr = self._thisAddr
            self._thisAddr = cmd.getProgAddrAsInt()
            self._diffAddr = self._thisAddr - self._prevAddr
            
            if (self._diffAddr == self._progIncr):
                print(f"N25Q{cmd.CommandName} Check: valid prog address"
                      f" increment by {self._diffAddr}", file=self._fhCheck)
            else:
                print(f"N25Q{cmd.CommandName} Check: invalid prog address"
                      f" increment by {self._diffAddr}", file=self._fhCheck)
        else:
            pass

    def _checkReadSeq(self, cmd):
        if (hasattr(cmd, 'getReadSequence')):
            self._seqCnt = cmd.getReadSequence()
            
            if (self._seqCnt == self._readIncr):
                print(f"N25Q{cmd.CommandName} Check: valid read data"
                      f" increment for {self._seqCnt} bytes\n", file=self._fhCheck)
            else:
                print(f"N25Q{cmd.CommandName} Check: invalid read data"
                      f" increment for {self._seqCnt} bytes\n", file=self._fhCheck)
        else:
            pass
        
    def _checkProgSeq(self, cmd):
        if (hasattr(cmd, 'getProgSequence')):
            self._seqCnt = cmd.getProgSequence()
            
            if (self._seqCnt == self._progIncr):
                print(f"N25Q{cmd.CommandName} Check: valid prog data"
                      f" increment for {self._seqCnt} bytes\n", file=self._fhCheck)
            else:
                print(f"N25Q{cmd.CommandName} Check: invalid prog data"
                      f" increment for {self._seqCnt} bytes\n", file=self._fhCheck)
        else:
            pass
    
    def checkValidateCommandBytes(self):
        for cmd in self._adssp.getFlashCmds():
            print(cmd, file=self._fhCheck)
            self._checkEraseAddr(cmd)
            self._checkReadAddr(cmd)
            self._checkProgAddr(cmd)
            self._checkReadSeq(cmd)
            self._checkProgSeq(cmd)
            print(file=self._fhCheck)
        self._fhCheck.close()

def mainPmodCLS(filename, partFlag):
    parser = PmodCLSTranslator(partFlag, filename)
    parser.parseWithAdssp()

def mainPmodSF3(filename, partFlag):
    
    validator = PmodSF3TesterValidator(filename)
    
    validator.parseWithAdssp()
    validator.checkValidateCommandBytes()

def usage():
    print("{} : <c | p | cp> <filename.txt>" .formatt(sys.argv[0]))
    print("{}".format(sys.argv[0]))
    sys.exit(1)

if __name__ == "__main__":
    if (len(sys.argv) == 1):
        partFlag = "c"
        pmodCLSfileNames = [\
        "ACL-Tester-Design-VHDL/CLS SPI Spy Capture of ACL Idle Display at 625 KHz SCK.txt", \
        "ACL-Tester-Design-VHDL/CLS SPI Spy Capture of ACL Free-Running Display at 625 KHz SCK.txt", \
        "ACL-Tester-Design-VHDL/CLS SPI Spy Capture of ACL Activity-Inactivity Display at 625 KHz SCK.txt", \
        ]
        
        for fileName in pmodCLSfileNames:
            mainPmodCLS(fileName, partFlag)
            
    else:
        usage()
