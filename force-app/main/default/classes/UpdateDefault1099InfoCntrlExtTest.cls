@IsTest
public with sharing class UpdateDefault1099InfoCntrlExtTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetSelectedIdsAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {

            testData.accounts.sort();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);            
            setController.setSelected(testData.accounts);
            UpdateDefault1099InfoCntrlExt controller = new UpdateDefault1099InfoCntrlExt(setController);
            system.assertEquals(controller.selectedRecords.size(), testData.accounts.size());                        
            String recordIds = '';
            for(SObject record : testData.accounts){
                recordIds += record.Id + ','; 
            }
            recordIds = recordIds.removeEnd(','); 
            system.assertEquals(controller.recordIds, recordIds);
        }
    }

    @IsTest
    static void testGetSelectedIdsContact() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {

            testData.contacts.sort();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.contacts);
            setController.setSelected(testData.contacts);
            UpdateDefault1099InfoCntrlExt controller = new UpdateDefault1099InfoCntrlExt(setController);
            system.assertEquals(controller.selectedRecords.size(), testData.contacts.size());            
            string recordIds = '';
            for(SObject record : testData.contacts){
                recordIds += record.Id + ','; 
            }
            recordIds = recordIds.removeEnd(','); 
            system.assertEquals(controller.recordIds, recordIds);
        }
    }

}