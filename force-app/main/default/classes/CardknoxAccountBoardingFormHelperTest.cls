@IsTest
public with sharing class CardknoxAccountBoardingFormHelperTest {
    public class MockFormSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody('{"appId": "173835","refnum": "brd121004075","tiers":["143_sandbox"],"status": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockFormFailedResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody('{"appId": "173835","refnum": "brd121004075","tiers":["143_sandbox"],"status": "Error"}');
            res.setStatusCode(200);
            return res;
        }
    }
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    static void testGetFormData(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CardknoxAccountBoardingFormHelper.AccountBoardingForm formData =
                    CardknoxAccountBoardingFormHelper.getFormData();
            Test.stopTest();
            Assert.areNotEqual(null,formData);
            Assert.areEqual(null,formData.businessPhone);
            Assert.areEqual(null,formData.productSold);
            Assert.areEqual(null,formData.ownershipType);
            Assert.areEqual(null,formData.dbaName);
            Assert.areEqual(null,formData.corporateName);
        }
    }
    @IsTest
    static void testSubmitFormSuccess(){
        Test.setMock(HttpCalloutMock.class, new MockFormSuccessResponse());
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {

            CardknoxAccountBoardingFormHelper.SignerInfo signersInfo1 = new CardknoxAccountBoardingFormHelper.SignerInfo();
            signersInfo1.firstName= 'Test Data';
            signersInfo1.lastName= 'Test Data';
            signersInfo1.ownershipPercentage= 50;
            signersInfo1.title= 'Test Data';
            signersInfo1.dateOfBirth= System.today();
            signersInfo1.ssn= '34565432';
            signersInfo1.signerStreet= 'Test Data';
            signersInfo1.signerCity= 'Test Data';
            signersInfo1.signerZip= '32323';
            signersInfo1.signerCountry= 'Test Data';
            signersInfo1.signerState= 'Test Data';
            signersInfo1.ownerCellPhone= '508-202-5000';

            CardknoxAccountBoardingFormHelper.SignerInfo signersInfo2 = new CardknoxAccountBoardingFormHelper.SignerInfo();
            signersInfo2.firstName= 'Test Data';
            signersInfo2.lastName= 'Test Data';
            signersInfo2.ownershipPercentage= 50;
            signersInfo2.title= 'Test Data';
            signersInfo2.dateOfBirth= System.today();
            signersInfo2.ssn= '34565432';
            signersInfo2.signerStreet= 'Test Data';
            signersInfo2.signerCity= 'Test Data';
            signersInfo2.signerZip= '32323';
            signersInfo2.signerCountry= 'Test Data';
            signersInfo2.signerState= 'Test Data';
            signersInfo2.ownerCellPhone= '508-202-5000';

            CardknoxAccountBoardingFormHelper.AccountBoardingForm formData = new 
                CardknoxAccountBoardingFormHelper.AccountBoardingForm();
            
            formData.corporateName= 'Test Corporate';
            formData.dbaName= 'Test DBA Name';
            formData.ownershipType= 'Partnership';
            formData.businessStartDate= System.today();
            formData.productSold= 'Test Data';
            formData.businessPhone= '508-202-5000';
            formData.taxId= 'Test Data';
            formData.annualCreditCardSales= 'Test Data';
            formData.website= 'Tes.com';
            formData.businessEmail= 'test@gmail.com';
            formData.agentName= 'Test Data';
            formData.agentEmail= 'test@gmail.com';
            formData.routingNumber= 'Test Data';
            formData.accountNumber= 'Test Data';
            formData.bankName= 'Test Data';
            formData.baStreet= 'Test Data';
            formData.baCity= 'Test Data';
            formData.baState= 'Test Data';
            formData.baZip= '33442';
            formData.baCountry= 'Test Data';
            formData.maStreet= 'Test Data';
            formData.maCity= 'Test Data';
            formData.maState= 'Test Data';
            formData.maZip= '23233';
            formData.maCountry= 'Test Data';
            formData.signerInfo = new List<CardknoxAccountBoardingFormHelper.SignerInfo>{signersInfo1,signersInfo2};
            formData.token= 'notoken' ;
            
            Test.startTest();
            CardknoxAccountBoardingFormHelper.submitForm(JSON.serialize(formData)); 
            Test.stopTest();
            Assert.areEqual(2,formData.signerInfo.size());
        }
    }
    @IsTest
    static void testSubmitFormFailed(){
        Test.setMock(HttpCalloutMock.class, new MockFormFailedResponse());
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {

            CardknoxAccountBoardingFormHelper.SignerInfo signersInfo = new CardknoxAccountBoardingFormHelper.SignerInfo();
            signersInfo.firstName= 'Test Data';
            signersInfo.lastName= 'Test Data';
            signersInfo.ownershipPercentage= 20;
            signersInfo.title= 'Test Data';
            signersInfo.dateOfBirth= System.today();
            signersInfo.ssn= '34565432';
            signersInfo.signerStreet= 'Test Data';
            signersInfo.signerCity= 'Test Data';
            signersInfo.signerZip= '32323';
            signersInfo.signerCountry= 'Test Data';
            signersInfo.signerState= 'Test Data';
            signersInfo.ownerCellPhone= '508-202-5000';

            CardknoxAccountBoardingFormHelper.AccountBoardingForm formData = new 
                CardknoxAccountBoardingFormHelper.AccountBoardingForm();
            
            formData.corporateName= 'Test Corporate';
            formData.dbaName= 'Test DBA Name';
            formData.ownershipType= 'Partnership';
            formData.businessStartDate= System.today();
            formData.productSold= 'Test Data';
            formData.businessPhone= '508-202-5000';
            formData.taxId= 'Test Data';
            formData.annualCreditCardSales= 'Test Data';
            formData.website= 'Tes.com';
            formData.businessEmail= 'test@gmail.com';
            formData.agentName= 'Test Data';
            formData.agentEmail= 'test@gmail.com';
            formData.routingNumber= 'Test Data';
            formData.accountNumber= 'Test Data';
            formData.bankName= 'Test Data';
            formData.baStreet= 'Test Data';
            formData.baCity= 'Test Data';
            formData.baState= 'Test Data';
            formData.baZip= '33442';
            formData.baCountry= 'Test Data';
            formData.maStreet= 'Test Data';
            formData.maCity= 'Test Data';
            formData.maState= 'Test Data';
            formData.maZip= '23233';
            formData.maCountry= 'Test Data';
            formData.signerInfo = new List<CardknoxAccountBoardingFormHelper.SignerInfo>{signersInfo};
            formData.token= 'notoken' ;
            
            Test.startTest();
            try{
                CardknoxAccountBoardingFormHelper.submitForm(JSON.serialize(formData)); 
            }catch(Exception e){
                Assert.areNotEqual(null,e);
                Assert.areEqual('Script-thrown exception',e.getMessage());
            }
            Test.stopTest();
        }
    }
}