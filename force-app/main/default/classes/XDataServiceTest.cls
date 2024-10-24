@IsTest
public class XDataServiceTest {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    private static void testQuery(){
        String query = 'SELECT Id, Name, '+
                    PACKAGE_QUALIFIER +'Status__c,' +
                    PACKAGE_QUALIFIER + 'Billing_State__c,' +
                    PACKAGE_QUALIFIER + 'Billing_Country__c  FROM '+
                    PACKAGE_QUALIFIER + 'Billing__c';
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        List<sObject> records = XDataService.query(query);
        Test.stopTest();

        for(sObject record : records){
            System.assertEquals('Posted', record.get(PACKAGE_QUALIFIER +'Status__c'));
        }
    }
    @IsTest
    private static void testUpsertRecords(){
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        XDataService.UpsertInfo info = XDataService.upsertData(JSON.serialize(testData.billingLines), '','','','');
        Test.stopTest();
        System.assertEquals(false, info.hasError);
        System.assertEquals(0, info.recordErrors.size());
    }
    @IsTest
    private static void testUpsertRecordsHasError(){
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        XDataService.UpsertInfo info = XDataService.upsertData(JSON.serialize(testData.billings),JSON.serialize(new List<sObject>{testData.contacts[0]}),'','','');
        Test.stopTest();
        System.assertEquals(true, info.hasError);
        System.assertEquals(5, info.records.size());
    }

    @IsTest
    private static void testErrorReduce(){
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        Test.startTest();
        String lines = '[' +
            '{' +
                '"rowKey":"0",' +
                '"attributes":{"type":"AcctSeed__Recurring_Journal_Entry_Line__c"},' +
                '"AcctSeed__Credit__c":1,' +
                '"AcctSeed__Recurring_Journal_Entry__c":"' + testData.recurringJournalEntries[0].Id + '"' + 
            '},' +
            '{' +
                '"rowKey":"1",' +
                '"attributes":{"type":"AcctSeed__Recurring_Journal_Entry_Line__c"},' +
                '"AcctSeed__Debit__c":1,' +
                '"AcctSeed__GL_Account__c":"' + testData.glAccounts[0].Id + '"' + 
            '}' +
        ']';

        XDataService.UpsertInfo result = XDataService.upsertData(lines, null,'','','');
        Test.stopTest();

        System.assert(result.hasError);
        System.assertEquals(2, result.records.size());
        System.assertEquals(2, result.recordErrors.keySet().size());
        System.assertEquals(
            Label.REQUIRED_FIELDS_ARE_MISSING + '. ["' + Recurring_Journal_Entry_Line__c.GL_Account__c.getDescribe().getLabel() + '"]', 
            result.recordErrors.get('0'));
        System.assertEquals(
            Label.REQUIRED_FIELDS_ARE_MISSING + '. ["' + Recurring_Journal_Entry_Line__c.Recurring_Journal_Entry__c.getDescribe().getLabel() + '"]', 
            result.recordErrors.get('1'));
    }
}