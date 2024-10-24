@IsTest
public with sharing class PayableInboundEmailHandlerTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testHandleInboundEmailForActiveBindingMdt(){
        Binding__mdt bindingMD = Binding__mdt.getInstance('EmailToPayableVerification');
        if(bindingMD.Is_Active__c){
            Messaging.InboundEmail email = new Messaging.InboundEmail() ;
            Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
            
            Contact cont = [SELECT Id FROM Contact LIMIT 1];
            cont.Email = 'test@example.com';
            update cont;
            email.subject = 'Re: Account Payable Invoice';
            email.fromAddress = 'test@example.com';
            email.plainTextBody = 'Test Invoice';
            email.toAddresses = new List<String>{'payableinvoice@example.com'};
            env.fromAddress = 'test@example.com';

            System.runAs ( new User(Id = UserInfo.getUserId()) ) {
                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
            }
            PayableInboundEmailHandler handler = new PayableInboundEmailHandler();
            Messaging.InboundEmailResult result = handler.handleInboundEmail(email, env);

            Assert.isNotNull([SELECT Id FROM ContentWorkSpace]);
            Assert.isNotNull([SELECT Id FROM ContentVersion]);
        }   
    }

    @IsTest
    private static void testHandleInboundEmail() {
        Binding__mdt bindingMD = Binding__mdt.getInstance('EmailToPayableVerification');
        if(!bindingMD.Is_Active__c){
            Messaging.InboundEmail email = new Messaging.InboundEmail() ;
            Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
            
            Contact cont = [SELECT Id FROM Contact LIMIT 1];
            cont.Email = 'test@example.com';
            update cont;
            
            Accounting_Period__c acctPeriods = [SELECT Id FROM Accounting_Period__c LIMIT 1];
            Date todayDate = System.today();
            acctPeriods.Start_Date__c = Date.newInstance(todayDate.year(), todayDate.month(), 1);
            acctPeriods.End_Date__c = acctPeriods.Start_Date__c.addMonths(1).addDays(-1);
            update acctPeriods;
            
            email.subject = 'Re: Account Payable Invoice';
            email.plainTextBody = 'From: <test@example.com> Test Invoice';
            email.toAddresses = new List<String>{'payableinvoice@example.com'};
            env.fromAddress = 'test@example.com';
            
            Messaging.InboundEmail.BinaryAttachment binaryAttachment = new Messaging.InboundEmail.BinaryAttachment();
            binaryAttachment.body = blob.valueOf('Test Binary Attachment');
            binaryAttachment.fileName = 'textfile1.txt';
            binaryAttachment.mimeTypeSubType = 'text/plain';
            email.binaryAttachments = new Messaging.inboundEmail.BinaryAttachment[] { binaryAttachment };
                
            Messaging.InboundEmail.TextAttachment textAttachment = new Messaging.InboundEmail.TextAttachment();
            textAttachment.body = 'Test Text Attachment';
            textAttachment.fileName = 'textfile2.txt';
            textAttachment.mimeTypeSubType = 'text/plain';
            email.textAttachments = new Messaging.inboundEmail.TextAttachment[] { textAttachment };
                
            PayableInboundEmailHandler handler = new PayableInboundEmailHandler();
            
            System.runAs ( new User(Id = UserInfo.getUserId()) ) {
                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
            }
            
            Messaging.InboundEmailResult result = handler.handleInboundEmail(email, env);
            System.assertEquals(true, result.success);
            Account_Payable__c payable = [SELECT Id FROM Account_Payable__c ];
            Assert.isNotNull(payable);
            Assert.isNotNull([SELECT Id FROM ContentDocument ]);
            Assert.isNotNull([SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId =: payable.Id ]);
        }
       
    }
   

    /*
    @IsTest
    private static void testHandleInboundEmail() {
        
        Messaging.InboundEmail email = new Messaging.InboundEmail() ;
        Messaging.InboundEnvelope env    = new Messaging.InboundEnvelope();
        
        Contact cont = [SELECT Id FROM Contact LIMIT 1];
        cont.Email = 'test@example.com';
        update cont;
        
        Accounting_Period__c acctPeriods = [SELECT Id FROM Accounting_Period__c LIMIT 1];
        Date todayDate = System.today();
        acctPeriods.Start_Date__c = Date.newInstance(todayDate.year(), todayDate.month(), 1);
        acctPeriods.End_Date__c = acctPeriods.Start_Date__c.addMonths(1).addDays(-1);
        update acctPeriods;
       
        email.subject = 'Re: Account Payable Invoice';
        email.fromAddress = 'test@example.com';
        email.plainTextBody = 'Test Invoice';
        email.toAddresses = new List<String>{'payableinvoice@example.com'};
        env.fromAddress = 'test@example.com';

        
        Messaging.InboundEmail.BinaryAttachment binaryAttachment = new Messaging.InboundEmail.BinaryAttachment();
        binaryAttachment.body = blob.valueOf('Test Binary Attachment');
        binaryAttachment.fileName = 'textfile1.txt';
        binaryAttachment.mimeTypeSubType = 'text/plain';
        email.binaryAttachments = new Messaging.inboundEmail.BinaryAttachment[] { binaryAttachment };
            
        Messaging.InboundEmail.TextAttachment textAttachment = new Messaging.InboundEmail.TextAttachment();
        textAttachment.body = 'Test Text Attachment';
        textAttachment.fileName = 'textfile2.txt';
        textAttachment.mimeTypeSubType = 'text/plain';
        email.textAttachments = new Messaging.inboundEmail.TextAttachment[] { textAttachment };
    
        PayableInboundEmailHandler handler = new PayableInboundEmailHandler();
        
        System.runAs (new User(Id = UserInfo.getUserId()) ) {
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
        }
        
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, env);
        System.assertEquals(true, result.success);
        // Account_Payable__c payable = [SELECT Id FROM Account_Payable__c ];
        // Assert.isNotNull(payable);
        // Assert.isNotNull([SELECT Id FROM ContentDocument ]);
        // Assert.isNotNull([SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId =: payable.Id ]);
    }
    */
}