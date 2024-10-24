@IsTest
public class OFXFileParserTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest 
    public static void testIsValidFileFormatError() {
        String file = 'OFXRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO<MESSAGE>The user is authentic; operation succeeded.</STATUS><DTSERVER>20150110155926.012[-6:CST]<LANGUAGE>ENG<FI><ORG>Elan Financial Services<FID>10308</FI></SONRS></SIGNONMSGSRSV1><CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>9C24C10F01D88DB70000014AD27DD889E4DE<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>4798510047411448</CCACCTFROM><BANKTRANLIST><DTSTART>20140531190000.000[-5:CDT]<DTEND>20150109180000.000[-6:CST]<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-48.06<FITID>2014-06-02-20.33.17.480941<NAME>SHELL OIL 57542187901 ELLICOTT C<MEMO>24316054152548772010336; 05542;</STMTTRN><STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-64.63<FITID>2014-06-02-20.33.17.486974<NAME>MAPLE LAWN BP FULTON<MEMO>24122544152740152920044; 05542;</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-16.00<DTASOF>20141107000000[0:GMT]</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';
        
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(false,theParser.isValidFileFormat());
    }

    @IsTest 
    public static void testIsValidFileFormatSuccess() {
        String file = 'OFXHEADER:100\nDATA:OFXSGML\nVERSION:102\nSECURITY:NONE\nENCODING:USASCII\nCHARSET:1252\nCOMPRESSION:NONE\nOLDFILEUID:NONE\nNEWFILEUID:NONE\n<OFX><SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO<MESSAGE>The user is authentic; operation succeeded.</STATUS><DTSERVER>20150110155926.012[-6:CST]<LANGUAGE>ENG<FI><ORG>Elan Financial Services<FID>10308</FI></SONRS></SIGNONMSGSRSV1><CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>9C24C10F01D88DB70000014AD27DD889E4DE<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>4798510047411448</CCACCTFROM><BANKTRANLIST><DTSTART>20140531190000.000[-5:CDT]<DTEND>20150109180000.000[-6:CST]<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-48.06<FITID>2014-06-02-20.33.17.480941<NAME>SHELL OIL 57542187901 ELLICOTT C<MEMO>24316054152548772010336; 05542;</STMTTRN><STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-64.63<FITID>2014-06-02-20.33.17.486974<NAME>MAPLE LAWN BP FULTON<MEMO>24122544152740152920044; 05542;</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-16.00<DTASOF>20141107000000[0:GMT]</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';
        
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(true,theParser.isValidFileFormat());
    }

    @IsTest 
    public static void testGetTransactionCountEmptyFileError() {
        String file = '';
        
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(0,theParser.getTransactionCount());
    }

    @IsTest 
    public static void testGetTransactionCountOneLineSucccess() {
        String file = 'OFXHEADER:100\nDATA:OFXSGML\nVERSION:102\nSECURITY:NONE\nENCODING:USASCII\nCHARSET:1252\nCOMPRESSION:NONE\nOLDFILEUID:NONE\nNEWFILEUID:NONE\n<OFX><SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO<MESSAGE>The user is authentic; operation succeeded.</STATUS><DTSERVER>20150110155926.012[-6:CST]<LANGUAGE>ENG<FI><ORG>Elan Financial Services<FID>10308</FI></SONRS></SIGNONMSGSRSV1><CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>9C24C10F01D88DB70000014AD27DD889E4DE<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>4798510047411448</CCACCTFROM><BANKTRANLIST><DTSTART>20140531190000.000[-5:CDT]<DTEND>20150109180000.000[-6:CST]<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-48.06<FITID>2014-06-02-20.33.17.480941<NAME>SHELL OIL 57542187901 ELLICOTT C<MEMO>24316054152548772010336; 05542;</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-16.00<DTASOF>20141107000000[0:GMT]</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';
        
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(1,theParser.getTransactionCount());
    }    
    
    @IsTest 
    public static void testGetTransactionCountMultipleLineSucccess() {
        String file = 'OFXHEADER:100\nDATA:OFXSGML\nVERSION:102\nSECURITY:NONE\nENCODING:USASCII\nCHARSET:1252\nCOMPRESSION:NONE\nOLDFILEUID:NONE\nNEWFILEUID:NONE\n<OFX><SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO<MESSAGE>The user is authentic; operation succeeded.</STATUS><DTSERVER>20150110155926.012[-6:CST]<LANGUAGE>ENG<FI><ORG>Elan Financial Services<FID>10308</FI></SONRS></SIGNONMSGSRSV1><CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>9C24C10F01D88DB70000014AD27DD889E4DE<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>4798510047411448</CCACCTFROM><BANKTRANLIST><DTSTART>20140531190000.000[-5:CDT]<DTEND>20150109180000.000[-6:CST]<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-48.06<FITID>2014-06-02-20.33.17.480941<NAME>SHELL OIL 57542187901 ELLICOTT C<MEMO>24316054152548772010336; 05542;</STMTTRN><STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-64.63<FITID>2014-06-02-20.33.17.486974<NAME>MAPLE LAWN BP FULTON<MEMO>24122544152740152920044; 05542;</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-16.00<DTASOF>20141107000000[0:GMT]</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';
        
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(2,theParser.getTransactionCount());
    }

    @IsTest 
    public static void testGetFileFormatMessageSucccess() {
        String file = 'OFXHEADER:100\nDATA:OFXSGML\nVERSION:102\nSECURITY:NONE\nENCODING:USASCII\nCHARSET:1252\nCOMPRESSION:NONE\nOLDFILEUID:NONE\nNEWFILEUID:NONE\n<OFX><SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO<MESSAGE>The user is authentic; operation succeeded.</STATUS><DTSERVER>20150110155926.012[-6:CST]<LANGUAGE>ENG<FI><ORG>Elan Financial Services<FID>10308</FI></SONRS></SIGNONMSGSRSV1><CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>9C24C10F01D88DB70000014AD27DD889E4DE<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>4798510047411448</CCACCTFROM><BANKTRANLIST><DTSTART>20140531190000.000[-5:CDT]<DTEND>20150109180000.000[-6:CST]<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-48.06<FITID>2014-06-02-20.33.17.480941<NAME>SHELL OIL 57542187901 ELLICOTT C<MEMO>24316054152548772010336; 05542;</STMTTRN><STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-64.63<FITID>2014-06-02-20.33.17.486974<NAME>MAPLE LAWN BP FULTON<MEMO>24122544152740152920044; 05542;</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-16.00<DTASOF>20141107000000[0:GMT]</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';
        
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(OFXFileParser.FILE_FORMAT_ERROR,theParser.getFileFormatErrorMessage());
    } 

/*
    @IsTest 
    public static void testOFXFileParserError() {
        String file = 'OFXHEADER:100\nDATA:OFXSGML\nVERSION:102\nSECURITY:NONE\nENCODING:USASCII\nCHARSET:1252\nCOMPRESSION:NONE\nOLDFILEUID:NONE\nNEWFILEUID:NONE\n<OFX><SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO<MESSAGE>The user is authentic; operation succeeded.</STATUS><DTSERVER>20150110155926.012[-6:CST]<LANGUAGE>ENG<FI><ORG>Elan Financial Services<FID>10308</FI></SONRS></SIGNONMSGSRSV1><CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>9C24C10F01D88DB70000014AD27DD889E4DE<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>4798510047411448</CCACCTFROM><BANKTRANLIST><DTSTART>20140531190000.000[-5:CDT]<DTEND>20150109180000.000[-6:CST]<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-48.06<FITID>2014-06-02-20.33.17.480941<NAME>SHELL OIL 57542187901 ELLICOTT C<MEMO>24316054152548772010336; 05542;</STMTTRN><STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20140602120000.000<TRNAMT>-64.63<FITID>2014-06-02-20.33.17.486974<NAME>MAPLE LAWN BP FULTON<MEMO>24122544152740152920044; 05542;</STMTTRN></BANKTRANLIST><LEDGERBAL><BALAMT>-16.00<DTASOF>20141107000000[0:GMT]</LEDGERBAL></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>';

        //List<FinancialImportLineWrapper> lineWrapperList = new List<FinancialImportLineWrapper>();
        OFXFileParser theParser = new OFXFileParser(file);
        
        List<FinancialImportLineWrapper> lineWrapperList;
        
        Exception theEx;
        
        try {
            lineWrapperList = theParser.parse(); 
        }
        catch (Exception ex) {
            theEx = ex;
        }  
        
        System.assertEquals(OFXFileParser.FILE_FORMAT_ERROR,theEx.getMessage());
    } 
    */

    @IsTest 
    public static void testGetAmountSuccess() {
        OFXFileParser theParser = new OFXFileParser('');
        System.assertEquals(233.45, theParser.getAmount('233.45'));
        System.assertEquals(233.45, theParser.getAmount('233,45'));
        System.assertEquals(-233.45, theParser.getAmount('-233.45'));
        System.assertEquals(-233.45, theParser.getAmount('-233,45'));

        System.assertEquals(233.40, theParser.getAmount('233.40'));
        System.assertEquals(233.40, theParser.getAmount('233,40'));
        System.assertEquals(-233.40, theParser.getAmount('-233.40'));
        System.assertEquals(-233.40, theParser.getAmount('-233,40'));

        System.assertEquals(233.40, theParser.getAmount('233.4'));
        System.assertEquals(233.40, theParser.getAmount('233,4'));
        System.assertEquals(-233.40, theParser.getAmount('-233.4'));
        System.assertEquals(-233.40, theParser.getAmount('-233,4'));

        System.assertEquals(233.00, theParser.getAmount('233'));
        System.assertEquals(233.00, theParser.getAmount('233'));

        System.assertEquals(0.5, theParser.getAmount('0.5'));
        System.assertEquals(0.5, theParser.getAmount('0,5'));
        System.assertEquals(-0.5, theParser.getAmount('-0.5'));
        System.assertEquals(-0.5, theParser.getAmount('-0,5'));
    }

    @IsTest
    public static void testParseToTransactionModels() {
        String file = getCheckingOFX();
        OFXFileParser theParser = new OFXFileParser(file);
        System.assertEquals(true, theParser.isValidFileFormat());
        theParser.parseToTransactionModels();
        System.assertEquals(1, theParser.transactionModels.size());
        System.assertEquals('1000', theParser.transactionModels[0].checkNumber);
    }

    private static String getOfxHeader() {
        return
            'OFXHEADER:100\n' +
            'DATA:OFXSGML\n' +
            'VERSION:102\n' +
            'SECURITY:NONE\n' +
            'ENCODING:USASCII\n' +
            'CHARSET:1252\n' +
            'COMPRESSION:NONE\n' +
            'OLDFILEUID:NONE\n' +
            'NEWFILEUID:NONE\n';
    }

    private static String getCheckingOFX() {
        String result =
            getOfxHeader() +
            '<OFX>\n' +
                '<SIGNONMSGSRSV1>\n' +
                '<SONRS>\n' +
                '<STATUS>\n' +
                '<CODE>0</CODE>\n' +
                '<SEVERITY>INFO</SEVERITY>\n' +
                '</STATUS>\n' +
                '<DTSERVER>20051029101003</DTSERVER>\n' +
                '<LANGUAGE>ENG</LANGUAGE>\n' +
                '<DTPROFUP>19991029101003</DTPROFUP>\n' +
                '<DTACCTUP>20031029101003</DTACCTUP>\n' +
                '<FI>\n' +
                '<ORG>NCH</ORG>\n' +
                '<FID>1001</FID>\n' +
                '</FI>\n' +
                '</SONRS>\n' +
                '</SIGNONMSGSRSV1>\n' +
                '<BANKMSGSRSV1>\n' +
                '<STMTTRNRS>\n' +
                '<TRNUID>1001</TRNUID>\n' +
                '<STATUS>\n' +
                '<CODE>0</CODE>\n' +
                '<SEVERITY>INFO</SEVERITY>\n' +
                '</STATUS>\n' +
                '<STMTRS>\n' +
                '<CURDEF>USD</CURDEF>\n' +
                '<BANKACCTFROM>\n' +
                '<BANKID>121099999</BANKID>\n' +
                '<ACCTID>999988</ACCTID>\n' +
                '<ACCTTYPE>CHECKING</ACCTTYPE>\n' +
                '</BANKACCTFROM>\n' +
                '<BANKTRANLIST>\n' +
                '<DTSTART>20051001</DTSTART>\n' +
                '<DTEND>20051028</DTEND>\n' +
                '<STMTTRN>\n' +
                '<TRNTYPE>CHECK</TRNTYPE>\n' +
                '<DTPOSTED>20051004</DTPOSTED>\n' +
                ' <TRNAMT>-200.00</TRNAMT>\n' +
                ' <FITID>00002</FITID>\n' +
                ' <CHECKNUM>1000</CHECKNUM>\n' +
                '</STMTTRN>\n' +
                '</BANKTRANLIST>\n' +
                '<LEDGERBAL>\n' +
                '<BALAMT>200.29</BALAMT>\n' +
                '<DTASOF>200510291120</DTASOF>\n' +
                '</LEDGERBAL>\n' +
                '<AVAILBAL>\n' +
                '<BALAMT>200.29</BALAMT>\n' +
                '<DTASOF>200510291120</DTASOF>\n' +
                '</AVAILBAL>\n' +
                '</STMTRS>\n' +
                '</STMTTRNRS>\n' +
                '</BANKMSGSRSV1>\n' +
                '</OFX>';

        return result;
    }

}