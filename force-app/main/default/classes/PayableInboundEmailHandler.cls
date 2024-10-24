global with sharing class PayableInboundEmailHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email, Messaging.InboundEnvelope env) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        try{
            if(!FeatureManagementHandler.isPaymentServiceEnabled()){
                throw new PayableInboundEmailHandlerException(Label.PAYMENT_SERVICE_NOT_ENABLED);
            }
            String emailToPayableVerificationFile = 'EmailToPayableVerification';
            String libraryName = 'AS Files';
            Binding__mdt bindingMD = Binding__mdt.getInstance(emailToPayableVerificationFile);

            if(bindingMD.Is_Active__c){
            
                List<ContentWorkSpace> contentWorkspace = DomainUtils.getContentWorkSpace(libraryName); 
                if(contentWorkspace.isEmpty()){
                    contentWorkspace.add(new ContentWorkSpace(Name = libraryName));
                    insert contentWorkspace;
                }

                createContentVersion(email.plainTextBody,contentWorkspace[0].Id,emailToPayableVerificationFile);
                if(!Test.isRunningTest()){
                    updateEmailToPayableVerification(emailToPayableVerificationFile);
                }
            }else{
                Id accountPayableRecordId;
                List<ContentVersion> files = new List<ContentVersion>();
                List<ContentDocumentLink> links = new List<ContentDocumentLink>();
                String fromAddress = returnFromAddressForForwardedEmail(email.plainTextBody);
                fromAddress = String.isNotBlank(fromAddress) ? fromAddress : email.fromAddress;
                List<Contact> emailContact = queryContacts(fromAddress);
                List<EmailMessage> existingEmailMessage = email.references != null ? queryEmailMessages(email.references) : new List<EmailMessage>();


                if (!existingEmailMessage.isEmpty()) {
                    accountPayableRecordId = existingEmailMessage[0].RelatedToId;
                } else {
                    Account_Payable__c ap = new Account_Payable__c();
                    ap.Status__c = AccountPayableActions.STATUS_DRAFT;
                    if (!emailContact.isEmpty()) {
                        ap.Vendor__c = emailContact[0].AccountId;
                    }

                    SFDCSecurityUtils.insertCheckCRUDAndFLS(ap, new List<String>());
                    accountPayableRecordId = ap.Id;
                }
                EmailMessage eMessage = new EmailMessage();
                eMessage.relatedToId = accountPayableRecordId;
                eMessage.fromAddress = email.fromAddress;
                eMessage.fromName = email.fromName;
                eMessage.toAddress = email.toAddresses[0];
                eMessage.Subject = email.subject;
                eMessage.HtmlBody = email.htmlBody;
                eMessage.TextBody = email.plainTextBody;
                eMessage.MessageIdentifier = email.messageId;
                eMessage.MessageDate = System.now();
                SFDCSecurityUtils.insertCheckCRUDAndFLS(eMessage, new List<String>());

                if (email.binaryAttachments != null) {
                    for (Messaging.InboundEmail.BinaryAttachment att : email.binaryAttachments) {
                        files.add(addFile(att.fileName, att.body));
                    }
                }

                if (email.textAttachments != null) {
                    for (Messaging.InboundEmail.TextAttachment att : email.textAttachments) {
                        files.add(addFile(att.fileName, Blob.valueOf(att.body)));
                    }
                }

                if (!files.isEmpty()) {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(files, new List<String>());

                    for (ContentVersion file : queryContentVersions(files)) {
                        links.add(addLink(file.ContentDocumentId, accountPayableRecordId, 'I')); //To link with Account Payable Record
                        links.add(addLink(file.ContentDocumentId, eMessage.Id, 'V')); //To link with email message
                    }
                }

                if (!links.isEmpty()) {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(links, new List<String>());

                    // Set Default File Id on Account Payable
                    Account_Payable__c ap = new Account_Payable__c();
                    ap.Id = accountPayableRecordId;
                    ap.Default_File_Id__c = files[0].ExtId__c;
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(ap, new List<String>());
                }

                List<EmailMessage> eMessage1 = queryTasks(eMessage.Id);
                if (!eMessage1.isEmpty() && eMessage1[0].ActivityId != null) {
                    Task task = new Task();
                    task.Id = eMessage1[0].ActivityId;
                    task.Status = 'Completed';
                    task.WhoId = !emailContact.isEmpty() ? emailContact[0].Id : null;
                    task.ActivityDate = System.today();

                    SFDCSecurityUtils.updateCheckCRUDAndFLS(task, new List<String>());
                }
            }
            
            result.success = true;
            result.message = null;
            
        }catch(Exception ex){
            throw ex;
        }
        return result;
    }
 

    private static ContentVersion addFile(String fileName, Blob body) {
        ContentVersion file = new ContentVersion();
        file.Title = fileName;
        file.VersionData = body;
        file.PathOnClient = fileName;
        file.ExtId__c = UUID.getUUID();
        return file;
    }

    private static ContentDocumentLink addLink(Id ContentDocumentId, Id LinkedEntityId, String ShareType) {
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = ContentDocumentId;
        link.LinkedEntityId = LinkedEntityId;
        link.ShareType = ShareType;
        link.Visibility = 'AllUsers';
        return link;
    }
    private List<Contact> queryContacts(String fromEmailAddress) {
        List<String> queryFields = new List<String>{
                'Id',
                'Email',
                'AccountId'
        };

        String queryCondition = 'Email = :fromEmailAddress';

        SOQLBuilder theQuery = new SOQLBuilder(Contact.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);

        return (List<Contact>) Database.query(theQuery.toSOQL());
    }

    private List<ContentVersion> queryContentVersions(List<ContentVersion> files) {
        List<String> queryFields = new List<String>{
                'Id',
                'ContentDocumentId'
        };

        String queryCondition = 'Id IN :files';

        SOQLBuilder theQuery = new SOQLBuilder(ContentVersion.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<ContentVersion>) Database.query(theQuery.toSOQL());
    }

    private List<EmailMessage> queryTasks(Id emailMessageId) {
        List<String> queryFields = new List<String>{
                'ActivityId'
        };

        String queryCondition = 'Id = :emailMessageId';

        SOQLBuilder theQuery = new SOQLBuilder(EmailMessage.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);

        return (List<EmailMessage>) Database.query(theQuery.toSOQL());
    }

    private List<EmailMessage> queryEmailMessages(List<String> emailReferences) {
        List<String> queryFields = new List<String>{
                'Id',
                'RelatedToId'
        };

        String queryCondition = 'MessageIdentifier IN : emailReferences';

        SOQLBuilder theQuery = new SOQLBuilder(EmailMessage.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);

        return (List<EmailMessage>) Database.query(theQuery.toSOQL());
    }

    private class PayableInboundEmailHandlerException extends Exception {
    }

    private static String returnFromAddressForForwardedEmail(String plainTextBody){
        String fromAddress = '';
        try{
            Pattern emailPattern = Pattern.compile('(?<=From:.*<)\\S+@\\S+\\.\\w+(?=>)');
            Matcher emailMatcher = emailPattern.matcher(plainTextBody);
            if (emailMatcher.find()){
                fromAddress = emailMatcher.group(0);
            }
        } catch (Exception e){

        }
        return fromAddress;
    }

    @future
    public static void updateEmailToPayableVerification(String bindingMetadataRecordName){
        Map<String, Object> metadataFieldValueMap = new Map<String, Object>();
        metadataFieldValueMap.put('Is_Active__c', false);
        CustomMetadataUtils.updateCustomMetadata('Binding__mdt',bindingMetadataRecordName, bindingMetadataRecordName,metadataFieldValueMap);
    }

    @future
    public static void createContentVersion(String emailBody, Id cwsId,String fileName){
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.VersionData = Blob.valueOf(emailBody);
        cv.PathOnClient = fileName + '.txt';
        cv.FirstPublishLocationId = cwsId;
        cv.ExtId__c = UUID.getUUID();
        insert cv;
    }

}