public with sharing abstract class AbstractStatementManager {
    private static final String CUSTOMER_STATEMENT_PDF_NAME_PREFIX = '_Outstanding_Statement_';
    private static final String ACTIVITY_STATEMENT_PDF_NAME_PREFIX = '_Activity_Statement_';
    @TestVisible
    private static final Integer CUSTOMER_NAME_LENGTH_LIMIT = 235;
    private static final Integer FILE_NAME_LENGTH_LIMIT = 255;
    @TestVisible
    private static final String BILLING_STATEMENT_PDF_NAME_PREFIX = '_Inv#_';
    @TestVisible
    private static final String PDF_EXTENSION = '.pdf';
    private static final String URL_PARAM_ID = 'id';
    private static final String URL_PARAM_SORT = 'sortField';
    @TestVisible
    private static final String PDF_EMAIL_STATUS_SENT = 'Sent';
    private static final String PDF_EMAIL_STATUS_UNSENT = 'Unsent';

    public static final Integer BATCH_CHUNK_SIZE = 5;
    public static final String NO_RECORDS_SELECTED_ERROR = Label.COMMON_NO_RECORDS_SELECTED_ERROR;
    public static final String EMAIL_SENT_SUCCESS = Label.INF_PDF_EMAIL_SENT_SUCCESS;
    public static final String NO_EMAIL_ERROR = Label.ERR_NO_EMAIL_FOR_CONTACT;
    public static final String EMAIL_LIMIT_ERROR = Label.ERR_EMAIL_LIMIT;
    public static final String MAIL_SUCCESS_MESSAGE_FOR_ACCOUNTS = Label.INF_MAIL_SUCCESS_MESSAGE_FOR_ACCOUNTS;
    public static final String MAIL_SUCCESS_MESSAGE_FOR_BILLINGS = Label.INF_MAIL_SUCCESS_MESSAGE_FOR_BILLINGS;
    public static final String ATTACH_SUCCESS_MESSAGE_FOR_ACCOUNTS = Label.INF_ATTACHED_SUCCESS_MESSAGE_FOR_ACCOUNTS;
    public static final String ATTACH_SUCCESS_MESSAGE_FOR_BILLINGS = Label.INF_ATTACHED_SUCCESS_MESSAGE_FOR_BILLINGS;
    public static final String NO_CONTACT_EMAIL_SET_ERROR = Label.ERR_CONTACT_OR_CONTACT_EMAIL_NOT_BILLING;

    public static final String BILLINGS = Label.COMMON_BILLINGS;
    public static final String STATEMENTS = Label.COMMON_STATEMENTS;
    public static final String REPORT_SUBJECT = Label.INF_EMAIL_REPORT_SUBJECT;
    public static final String REPORT_NMB_SUBM = '{NMB_SUBM}';
    public static final String REPORT_NMB_SENT = '{NMB_SENT}';
    public static final String REPORT_NMB_UNSENT = '{NMB_UNSENT}';
    public static final String REPORT_LOG_SOURCE_NMB = '{SOURCE_NMB}';
    public static final String REPORT_LOG_SOURCE_DESC = '{SOURCE_DESC}';
    public static final String REPORT_LOG_TEMPLATE_HEADER = Label.INF_UNSENT_EMAILS_LOG;
    public static final String BILLINGS_REPORT_TEMPLATE = String.format(Label.INF_BILLINGS_REPORT_TEMPLATE, 
                                                          new List<Object>{REPORT_NMB_SUBM, '\r\n', REPORT_NMB_SENT, '\r\n', REPORT_NMB_UNSENT});

    public static final String REPORT_TEMPLATE = String.format(Label.INF_BILLINGS_REPORT_TEMPLATE, 
    new List<Object>{REPORT_NMB_SUBM, '\r\n', REPORT_NMB_SENT, '\r\n', REPORT_NMB_UNSENT});

    public List<SelectOption> orgWideEmailSelectOptions {get; private set;}
    public Map<String, OrgWideEmailAddress> orgWideEmailMap {get; private set;}
    public String selectedOrgWideEmailAddress {get; set;}
    public Boolean fromAddressPicklistEnabled {get; private set;}

    public List<CustomEmailAttachment> customEmailAttachments {get; set;}
    public String serializedCustomEmailAttachments {get; set;}
    public Boolean isMultiCurrencyEnabled {get; set;}

    public Billing__c generateStatementAsOfProxyRecord {
        get {
            if (generateStatementAsOfProxyRecord == null || generateStatementAsOfProxyRecord.Discount_Due_Date__c == null) {
                generateStatementAsOfProxyRecord = new Billing__c(Discount_Due_Date__c = System.today());
            }
            return generateStatementAsOfProxyRecord;
        }
        set;
    }

    //Common methods
    private void checkAttachmentsSize() {
        Integer totalSizeOfAttachments = 0;
        for (CustomEmailAttachment customEmailAttachment : customEmailAttachments) {
            totalSizeOfAttachments += customEmailAttachment.fileSize;
        }
        if (totalSizeOfAttachments > EmailFileSelectorController.FILE_SIZE_LIMIT) {
            throw new StatementPdfException(EmailFileSelectorController.TOTAL_FILES_SIZE_LIMIT_ERROR_MESSAGE);
        }
        if (customEmailAttachments.size() > EmailFileSelectorController.FILE_QUANTITY_LIMIT) {
            throw new StatementPdfException(EmailFileSelectorController.TOTAL_ATTACHMENTS_QUANTITY_LIMIT_ERROR_MESSAGE);
        }
    }

    protected void processCustomEmailAttachments() {
        if (!String.isBlank(serializedCustomEmailAttachments)) {
            customEmailAttachments = (List<CustomEmailAttachment>) JSON.deserialize(
                serializedCustomEmailAttachments, List<CustomEmailAttachment>.class
            );
            if (!customEmailAttachments.isEmpty()) {
                putFileContentInWrappedAttachments();
                checkAttachmentsSize();
            }
        }
    }

    private void putFileContentInWrappedAttachments() {
        Set<String> fileIds = new Set<String>();
        Map<String, CustomEmailAttachment> fileIdToWrappedAttachment = new Map<String, CustomEmailAttachment>();

        for (CustomEmailAttachment file : customEmailAttachments) {
            if (file.fileId != NULL) {
                fileIds.add(file.fileId);
                fileIdToWrappedAttachment.put(file.fileId, file);
            }
        }

        for (ContentVersion file : DomainUtils.getFilesById(fileIds)) {
            //fill fileBody property of all wrappers
            fileIdToWrappedAttachment.get(file.Id).fileBody = file.VersionData;
            fileIdToWrappedAttachment.get(file.Id).fileSize = file.ContentSize;
        }

        customEmailAttachments = fileIdToWrappedAttachment.values();
    }

    protected void bindFilesWithSourceRecord(Id sourceRecordId) {
        if (customEmailAttachments == NULL || customEmailAttachments.isEmpty()) {
            return;
        }

        Set<String> fileIds = new Set<String>();
        List<ContentDocumentLink> junctionRecords = new List<ContentDocumentLink>();

        for (CustomEmailAttachment file : customEmailAttachments) {
            if (file.fileId != NULL && !file.isLinkedWithEntity) {
                fileIds.add(file.fileId);
            }
        }

        for (ContentVersion file : DomainUtils.getFilesById(fileIds)) {
            ContentDocumentLink tempJunctionRecord = new ContentDocumentLink();
            tempJunctionRecord.ContentDocumentId = file.ContentDocumentId;
            tempJunctionRecord.LinkedEntityId = sourceRecordId;
            tempJunctionRecord.ShareType = 'I';
            tempJunctionRecord.Visibility = 'AllUsers';
            junctionRecords.add(tempJunctionRecord);
        }

        SFDCSecurityUtils.insertProxy(junctionRecords);

        //need to mark new attachments as "already linked" to prevent duplication error
        for (CustomEmailAttachment file : customEmailAttachments) {
            if (fileIds.contains(file.fileId)) {
                file.isLinkedWithEntity = true;
            }
        }
        //refresh serialized value for proxy input field
        serializedCustomEmailAttachments = JSON.serialize(customEmailAttachments);
    }

    protected void getOrgWideEmailSelectOptions(String pdfEmailAddress) {
        OrgWideEmailAddress fromPdfAddress;
        fromAddressPicklistEnabled = true;
        orgWideEmailSelectOptions = new List<SelectOption>();
        orgWideEmailMap = new Map<String, OrgWideEmailAddress>();
        orgWideEmailSelectOptions.add(new SelectOption(UserInfo.getUserEmail(), UserInfo.getUserEmail()));

        for (OrgWideEmailAddress addr : FinancialSuiteUtils.orgWideEmailAddressList) {
            if (!String.isBlank(pdfEmailAddress) && pdfEmailAddress == addr.Address) {
                fromPdfAddress = addr;
            }
            SelectOption emailSelectOption = new SelectOption(addr.Id, addr.DisplayName + '<' + addr.Address + '>');
            orgWideEmailSelectOptions.add(emailSelectOption);
            orgWideEmailMap.put(addr.Id, addr);
        }

        if (orgWideEmailSelectOptions.size() == 1) {
            fromAddressPicklistEnabled = false;
            selectedOrgWideEmailAddress = UserInfo.getUserEmail();
        }

        if (fromPdfAddress != NULL) {
            selectedOrgWideEmailAddress = fromPdfAddress.Id;
        }
    }

    protected Boolean processResults(Map<Id, StatementResult> results) {
        return results.values()[0].isSuccess;
    }

    protected String getCCAddresses(Id accountId) {
        Map<Id, Set<String>> accountIdToEmails = FinancialSuiteUtils.getEmailAddressesFromAccountContact(
            new Set<Id>{accountId}, new Set<String>{'Billing Contact'}
        );

        if (accountIdToEmails.get(accountId) != NULL && !accountIdToEmails.get(accountId).isEmpty()) {
            List<String> emails = new List<String>(accountIdToEmails.get(accountId));
            return String.join(emails, ',');
        }
        else {
            return NULL;
        }
    }

    //public method called from Financial Suite and ERP Service so that all PDfs have the same naming convention
    @TestVisible
    public static String formatFileName(String customerName, String typePrefix, String recordName ){
        String locale = getLocaleDateTimeFormatted();
        //the locale can vary in length so we need to back that length out of the overall length for long account names
        //content version title char limiit is 255.  If the combined length is greater than that trim the customer name
        if(customerName.length() + typePrefix.length() + recordName.length() + locale.length() + PDF_EXTENSION.length() > FILE_NAME_LENGTH_LIMIT){
            Integer customerNameLen = FILE_NAME_LENGTH_LIMIT - typePrefix.length() - recordName.length() - locale.length() - PDF_EXTENSION.length();
            customerName = customerName.substring(0, customerNameLen);
        }
        return customerName + typePrefix + recordName + locale + PDF_EXTENSION;
    }

    @TestVisible
    private static String getLocaleDateTimeFormatted(){
        return '_' + Datetime.now().format().replace(' ','_').replace('/', '-').replace('\\', '-').replace('.', '-').replace(',', '');
    }

    

    //Query records section ==============================
    private static Map<Id, Billing_Format__c> queryOutstandingFormatFromActualLedger(Set<Id> ledgerIds) {
        Map<Id, Billing_Format__c> result = new Map<Id, Billing_Format__c>();
        for (Ledger__c ledger : DomainUtils.getLedgerWithStatementFormatFieldsById(ledgerIds)) {
            result.put(ledger.Id, ledger.Billing_Outstanding_Statement_Format__r);
        }
        return result;
    }

    private static Map<Id, Billing_Format__c> queryActivityStatementFormatFromActualLedger(Set<Id> ledgerIds) {
        Map<Id, Billing_Format__c> result = new Map<Id, Billing_Format__c>();
        for (Ledger__c ledger : DomainUtils.getLedgerWithStatementFormatFieldsById(ledgerIds)) {
            result.put(ledger.Id, ledger.Billing_Activity_Statement_Format__r);
        }
        return result;
    }

    //Inner classes section ==============================
    public class StatementSet {
        private List<SObject> sourceRecords;
        private Set<Id> sourceRecordIds;
        private AbstractStatementManager.StatementType stType;
        @TestVisible
        private Map<Id, String> sourceToUrl;
        @TestVisible
        private Id ledgerId;
        private String baseURL;
        @TestVisible
        private String currencyIsoCode;
        @TestVisible
        private Map<String, String> customUrlParams;

        public List<Statement> statements {get; private set;}
        public Map<Id, StatementResult> statementResults {get; private set;}
        public Map<Id, Billing_Format__c> sourceIdToDefaultPdfFormat {get; private set;}
        public CustomEmailTemplate custEmailTempl {get; set;}
        public Map<Id, EmailTemplate> sourceToTemplate {get; set;}
        public Map<Id, Billing_Format__c> sourceToPfdFormat {get; set;}

        public StatementSet(List<SObject> sourceRecords, AbstractStatementManager.StatementType stType, String baseUrl) {
            this.statements = new List<Statement>();
            this.statementResults = new Map<Id, StatementResult>();
            this.sourceRecords = sourceRecords;
            this.sourceRecordIds = new Map<Id, SObject>(sourceRecords).keySet();
            this.stType = stType;
            this.ledgerId = LedgerHandler.getLedgerId();
            setDefaultPdfFormatMapping(this.ledgerId);//used for Customer Statements only
            this.baseURL = baseUrl;
            this.sourceToPfdFormat = getSourceToPdfFormatMapping();
            this.sourceToUrl = getSourceToPdfUrlMapping();
            this.sourceToTemplate = getSourceToEmailTemplateMapping();
            setDefaultCurrencyIsoCode();
            //init custom email template for the single context only
            if (this.sourceRecords.size() == 1) {
                this.custEmailTempl = new CustomEmailTemplate(
                    this.sourceToTemplate.get(sourceRecords[0].Id),
                    (Id) this.sourceRecords[0].get('Billing_Contact__c'),
                    this.sourceRecords[0].Id
                );
            }

            for (SObject sourceRecord : sourceRecords) {
                statements.add(
                    new Statement(
                        sourceRecord,
                        sourceToPfdFormat.get(sourceRecord.Id),
                        sourceToUrl.get(sourceRecord.Id),
                        sourceToTemplate.get(sourceRecord.Id),
                        stType,
                        ledgerId,
                        currencyIsoCode
                    )
                );
            }
            setCurrencyBySelectedCurrencyIsoCode(this.currencyIsoCode);
        }

        //this constructor is used for Customer Statements from Account List View only
        public StatementSet(List<SObject> sourceRecords,
            Map<Id, Id> sourceRecordIdToLedgerId,
            Map<Id, String> sourceRecordIdToCurrencyIsoCode,
            AbstractStatementManager.StatementType stType,
            String baseUrl,
            Map<String, String> customUrlParams) {

            this.statements = new List<Statement>();
            this.statementResults = new Map<Id, StatementResult>();
            this.sourceRecords = sourceRecords;
            this.sourceRecordIds = new Map<Id, SObject>(sourceRecords).keySet();
            this.stType = stType;
            this.baseURL = baseUrl;
            setDefaultPdfFormatMapping(sourceRecordIdToLedgerId);
            this.sourceToPfdFormat = getSourceToPdfFormatMapping();
            this.sourceToUrl = getSourceToPdfUrlMapping();
            this.sourceToTemplate = getSourceToEmailTemplateMapping();

            for (SObject sourceRecord : sourceRecords) {
                statements.add(
                    new Statement(
                        sourceRecord,
                        sourceToPfdFormat.get(sourceRecord.Id),
                        sourceToUrl.get(sourceRecord.Id),
                        sourceToTemplate.get(sourceRecord.Id),
                        stType,
                        sourceRecordIdToLedgerId.get(sourceRecord.Id),
                        sourceRecordIdToCurrencyIsoCode.get(sourceRecord.Id)
                    ).setCustomUrlParams((customUrlParams))
                );
            }
        }

        public void setDefaultPdfFormatMapping(Id aLedgerId) {
            Map<Id, Id> sourceRecordIdToLedgerId = new Map<Id, Id>();
            for (SObject sourceRecord : sourceRecords) {
                sourceRecordIdToLedgerId.put(sourceRecord.Id, aLedgerId);
            }
            setDefaultPdfFormatMapping(sourceRecordIdToLedgerId);
        }

        public void setDefaultCurrencyIsoCode() {
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                for (SObject sourceRecord : sourceRecords) {
                    if (sourceRecord.getSobjectType() == Account.SObjectType && stType == StatementType.OUTSTANDING) {
                        if (sourceRecord.get('Outstanding_Statement_Format__c') == NULL) {
                            //take default from Default Ledger
                            this.currencyIsoCode = LedgerHandler.getLedgerCurrency(this.ledgerId);
                        }
                        else {//take Outstanding PDF Format populated on Account record
                            this.currencyIsoCode = (String) sourceRecord.get('CurrencyIsoCode');
                        }
                    }
                    else if (sourceRecord.getSobjectType() == Account.SObjectType && stType == StatementType.ACTIVITY) {
                        if (sourceRecord.get('Activity_Statement_Format__c') == NULL) {
                            //take default from Default Ledger
                            this.currencyIsoCode = LedgerHandler.getLedgerCurrency(this.ledgerId);
                        }
                        else {//take Activity PDF Format populated on Account record
                            this.currencyIsoCode = (String) sourceRecord.get('CurrencyIsoCode');
                        }
                    }
                }
            }
        }

        public void setDefaultPdfFormatMapping(Map<Id, Id> sourceRecordIdToLedgerId) {
            if (stType == StatementType.BILLING) {
                return;
            }

            Map<Id, Billing_Format__c> ledgerIdToBillingFormat;
            if (stType == StatementType.ACTIVITY) {
                ledgerIdToBillingFormat = queryActivityStatementFormatFromActualLedger(new Set<Id>(sourceRecordIdToLedgerId.values()));
            }
            else if (stType == StatementType.OUTSTANDING) {
                ledgerIdToBillingFormat = queryOutstandingFormatFromActualLedger(new Set<Id>(sourceRecordIdToLedgerId.values()));
            }

            this.sourceIdToDefaultPdfFormat = new Map<Id, Billing_Format__c>();
            for (Id sourceRecordId : sourceRecordIdToLedgerId.keySet()) {
                Id ledgerId = sourceRecordIdToLedgerId.get(sourceRecordId);
                this.sourceIdToDefaultPdfFormat.put(sourceRecordId, ledgerIdToBillingFormat.get(ledgerId));
            }
        }

        public void setCurrencyBySelectedCurrencyIsoCode(String currencyIsoCode) {
            this.currencyIsoCode = currencyIsoCode;
            for (Statement statement : statements) {
                statement.currencyIsoCode = currencyIsoCode;
            }
        }

        public void setLedgerBySelectedLedgerId(Id ledgerId) {
            this.ledgerId = ledgerId;
            for (Statement statement : statements) {
                statement.ledgerId = ledgerId;
            }
        }

        public void setDefaultPdfByPdfId(Id pdfFormatId) {
            setDefaultPdfFormatMappingByPdfId(pdfFormatId);
            this.sourceToPfdFormat = this.sourceIdToDefaultPdfFormat;
            this.sourceToUrl = getSourceToPdfUrlMapping();
            this.sourceToTemplate = getSourceToEmailTemplateMapping();
            for (Statement statement : statements) {
                statement.pdfFormat = sourceToPfdFormat.get(statement.source.Id);
                statement.urlPDF = sourceToUrl.get(statement.source.Id);
                statement.emailTemplate = sourceToTemplate.get(statement.source.Id).Id;
            }
        }

        public void setDefaultPdfFormatMappingByPdfId(Id pdfFormatId) {
            this.sourceIdToDefaultPdfFormat = new Map<Id, Billing_Format__c>();
            List<Billing_Format__c> billFormat = DomainUtils.getBillingFormatsById(new Set<Id> {pdfFormatId});
            for (Id sourceRecordId : sourceRecordIds) {
                this.sourceIdToDefaultPdfFormat.put(sourceRecordId, billFormat[0]);
            }
        }

        private Map<Id, Billing_Format__c> getSourceToPdfFormatMapping() {
            Map<Id, Billing_Format__c> result = new Map<Id, Billing_Format__c>();

            for (SObject sourceRecord : sourceRecords) {
                if (sourceRecord.getSobjectType() == Billing__c.SObjectType) {
                    result.put(sourceRecord.Id, (Billing_Format__c) sourceRecord.getSObject('Billing_Format__r'));
                }
                else if (sourceRecord.getSobjectType() == Account.SObjectType && stType == StatementType.OUTSTANDING) {
                    Billing_Format__c outstandingPdfFormat;
                    if (sourceRecord.get('Outstanding_Statement_Format__c') == NULL) {
                        //take default from Default Ledger
                        result.put(sourceRecord.Id, sourceIdToDefaultPdfFormat.get(sourceRecord.Id));
                    }
                    else {//take Outstanding PDF Format populated on Account record
                        result.put(sourceRecord.Id, (Billing_Format__c) sourceRecord.getSObject('Outstanding_Statement_Format__r'));
                    }
                }
                else if (sourceRecord.getSobjectType() == Account.SObjectType && stType == StatementType.ACTIVITY) {
                    if (sourceRecord.get('Activity_Statement_Format__c') == NULL) {
                        //take default from Default Ledger
                        result.put(sourceRecord.Id, sourceIdToDefaultPdfFormat.get(sourceRecord.Id));
                    }
                    else {//take Activity PDF Format populated on Account record
                        result.put(sourceRecord.Id, (Billing_Format__c) sourceRecord.getSObject('Activity_Statement_Format__r'));
                    }
                }
            }

            return result;
        }

        @TestVisible
        private Map<Id, String> getSourceToPdfUrlMapping() {
            Map<Id, String> result = new Map<Id, String>();
            Set<String> allPageNames = new Set<String>();

            for (Id sourceRecordId : sourceRecordIds) {
                if (sourceToPfdFormat.get(sourceRecordId) != NULL
                        && sourceToPfdFormat.get(sourceRecordId).Visualforce_PDF_Page__c != NULL) {

                    allPageNames.add(sourceToPfdFormat.get(sourceRecordId).Visualforce_PDF_Page__c);
                }
            }

            Map<String, String> pageUrls;
            if (String.isNotBlank(baseURL) && baseURL.toLowerCase() == GlobalVariables.APEX_URL_PATH) {
                // the base url is '/apex/'
                // construct a partial url => '/apex/c__MyPageName'
                pageUrls = buildPartialUrlLookup(allPageNames);
            } else { 
                // construct a full url => 'https://something.visualforce.com/apex/c__MyPageName'
                pageUrls = FinancialSuiteUtils.getPageAPINameToFullVFPageURL(allPageNames, baseURL);
            }

            for (Id sourceRecordId : sourceRecordIds) {
                result.put(
                    sourceRecordId,
                    pageUrls.get(sourceToPfdFormat.get(sourceRecordId).Visualforce_PDF_Page__c)
                );
            }
            return result;
        }

        private Map<Id, EmailTemplate> getSourceToEmailTemplateMapping() {
            Map<Id, EmailTemplate> result = new Map<Id, EmailTemplate>();
            Map<String, EmailTemplate> templateDevNameToId = new Map<String, EmailTemplate>();
            Set<String> templateDevNames = new Set<String>();

            for (Id sourceRecordId : sourceRecordIds) {
                templateDevNames.add(sourceToPfdFormat.get(sourceRecordId).Default_Email_Template__c);
            }

            for (EmailTemplate emailTmpl : DomainUtils.getEmailTemplatesByDeveloperName(templateDevNames)) {
                templateDevNameToId.put(emailTmpl.DeveloperName, emailTmpl);
            }

            for (Id sourceRecordId : sourceRecordIds) {
                result.put(
                    sourceRecordId,
                    templateDevNameToId.get(sourceToPfdFormat.get(sourceRecordId).Default_Email_Template__c)
                );
            }
            return result;
        }

        public Map<Id, StatementResult> savePDFs(Boolean needSendEmail) {
            statementResults.clear();
            Map<Id, ContentVersion> fileMap = new Map<Id, ContentVersion>();
            List<Messaging.SingleEmailMessage> mails;
            if (needSendEmail) {
                mails = new List<Messaging.SingleEmailMessage>();
            }
            if (statements.isEmpty()) {
                throw new StatementPdfException(NO_RECORDS_SELECTED_ERROR);
            }
            try {
                SObjectType sObjType = statements[0].source.getSObjectType();
                if (sObjType == Billing__c.getSObjectType()) {
                    Set<Id> sourceIds = new Set<Id>();
                    for (Statement eachStatement : statements) {
                        sourceIds.add(eachStatement.source.Id);
                    }
                    List<AggregateResult> results = DomainUtils.countLinesByParentIds(String.valueOf(Billing_Line__c.getSObjectType()), String.valueOf(Billing_Line__c.Billing__c), sourceIds);
                    Map<Id, Integer> countLinesByParentIds = new Map<Id, Integer>();
                    for (AggregateResult result : results) {
                        countLinesByParentIds.put((Id)result.get('refToParent'), (Integer)result.get('c0unt'));
                    }
                    for (Statement eachStatement : statements) {
                        if (countLinesByParentIds.get(eachStatement.source.Id) > 10000) {
                            processStatementResults(
                                    false,
                                    eachStatement.source,
                                    String.format(
                                            Label.ERR_COLLECTION_SIZE_EXCEEDS_LIMIT,
                                            new List<String>{String.valueOf(countLinesByParentIds.get(eachStatement.source.Id))}
                                    )
                            );
                        }
                    }
                }
                for (Statement eachStatement : statements) {
                    if (statementResults.containsKey(eachStatement.source.Id)) continue;
                    if (!needSendEmail
                            || (needSendEmail
                                    && eachStatement.recipient != NULL
                                    && eachStatement.recipient.Email != NULL)) {

                        Blob pdf = eachStatement.getPDF();
                        fileMap.put(eachStatement.source.Id, eachStatement.getFile(pdf));

                        if (mails != NULL) {
                            Messaging.SingleEmailMessage mail;
                            try {
                                mail = eachStatement.getEmail(pdf);
                                if (mail != NULL) {
                                    mails.add(mail);
                                }
                            }
                            catch (StatementPdfException ex) {
                                processStatementResults(false, eachStatement.source, ex.getMessage());
                            }
                        }
                    } else if (needSendEmail && (eachStatement.recipient == NULL || eachStatement.recipient.Email == NULL)) {
                        processStatementResults(false, eachStatement.source, NO_CONTACT_EMAIL_SET_ERROR);
                    }
                }
                if (!fileMap.isEmpty()) {
                    saveFiles(fileMap);
                }
                if (mails != NULL) {
                    Map<String, Set<String>> targetObjectIdByWhatId = getTargetObjectIdByWhatIdMap(mails);
                    //Mailing
                    List<Messaging.SendEmailResult> mailingResults = Messaging.sendEmail(mails, false);
                    for (Messaging.SendEmailResult rItem : mailingResults) {
                        if (!rItem.isSuccess()) {
                            List<Messaging.SendEmailError> errs = rItem.getErrors();
                            for (String sourceId : targetObjectIdByWhatId.get(errs[0].getTargetObjectId())) {
                                processStatementResults(sourceId, errs);
                            }
                        }
                    }
                }

                //For Billings ONLY==============
                if (sObjType == Billing__c.SObjectType && needSendEmail) {
                    List<Billing__c> billsForUpdate = new List<Billing__c>();
                    for (Statement eachStatement : statements) {
                        if (!statementResults.containsKey(eachStatement.source.Id)) {
                            eachStatement.source.put('PDF_Email_Status__c', PDF_EMAIL_STATUS_SENT);
                        }
                        else {
                            eachStatement.source.put('PDF_Email_Status__c', PDF_EMAIL_STATUS_UNSENT);
                            setEmailStatementResult(statementResults.get(eachStatement.source.Id), eachStatement.source);
                        }
                        billsForUpdate.add((Billing__c) eachStatement.source);
                    }

                    SFDCSecurityUtils.updateCheckCRUDAndFLS(billsForUpdate, new List<String>{
                        'PDF_Email_Status__c'
                    });
                }

                //For Account ONLY==============
                if (sObjType == Account.SObjectType && needSendEmail) {
                    List<Account> accountsForUpdate = new List<Account>();
                    for (Statement eachStatement : statements) {
                        if (!statementResults.containsKey(eachStatement.source.Id)) {
                            eachStatement.source.put('Statement_Needed__c', 'No');
                            eachStatement.source.put('Last_Statement_Sent__c', System.today());
                        }
                        else {
                            setEmailStatementResult(statementResults.get(eachStatement.source.Id), eachStatement.source);
                        }
                        // Create a clone with only values of interest.
                        // If the Account is a Person Account then the Name field 
                        // is a compound field (FirstName + LastName) and not 
                        // updateable, so an error will occur. StripInaccessible will
                        // not work here because the name field is still updateable for 
                        // regular Accounts.
                        Account original = (Account) eachStatement.source;
                        accountsForUpdate.add(new Account(
                            Id = original.Id, 
                            Statement_Needed__c = original.Statement_Needed__c,
                            Last_Statement_Sent__c = original.Last_Statement_Sent__c
                        ));
                    }

                    SFDCSecurityUtils.updateCheckCRUDAndFLS(accountsForUpdate, new List<String>{
                        'Statement_Needed__c',
                        'Last_Statement_Sent__c'
                    });
                }

                //Process successful result
                for (Statement eachStatement : statements) {
                    if (!statementResults.containsKey(eachStatement.source.Id)) {
                        processStatementResults(true, eachStatement.source, NULL);
                    }
                }
            }
            catch (Exception ex) {
                if (needSendEmail) {
                    for (Statement eachStatement : statements) {
                        if (!statementResults.containsKey(eachStatement.source.Id)) {
                            processStatementResults(false, eachStatement.source, ex.getMessage());
                        }
                        else {
                            statementResults.get(eachStatement.source.Id).messages.add(ex.getMessage());
                        }
                    }
                }
            }
            return statementResults;
        }

        private Map<String, Set<String>> getTargetObjectIdByWhatIdMap(List<Messaging.SingleEmailMessage> mails) {
            Map<String, Set<String>> result = new Map<String, Set<String>>();
            for (Messaging.SingleEmailMessage singleMail : mails) {
                if (!result.containsKey(singleMail.getTargetObjectId())) {
                    result.put(singleMail.getTargetObjectId(), new Set<String> {singleMail.getWhatId()});
                }
                else {
                    result.get(singleMail.getTargetObjectId()).add(singleMail.getWhatId());
                }
            }
            return result;
        }

        private void setEmailStatementResult(StatementResult result, SObject sourceRecord) {
            result.sourceId = sourceRecord.Id;
            result.sourceName = (String) sourceRecord.get('Name');
        }

        @TestVisible
        private void saveFiles(Map<Id, ContentVersion> contVersionMap) {
            SFDCSecurityUtils.insertProxy(contVersionMap.values());
            //query ContentVersion records in order to have ContentDocumentId populated on them
            Set<Id> fileIds = new Map<Id, ContentVersion>(contVersionMap.values()).keySet();
            Map<Id, ContentVersion> contentVersionInDB = new Map<Id, ContentVersion>(
                DomainUtils.getFilesById(fileIds)
            );

            List<ContentDocumentLink> junctionRecords = new List<ContentDocumentLink>();
            for (Id sourceId : contVersionMap.keySet()) {
                ContentDocumentLink tempJunctionRecord = new ContentDocumentLink();
                tempJunctionRecord.ContentDocumentId = contentVersionInDB.get(contVersionMap.get(sourceId).Id).ContentDocumentId;
                tempJunctionRecord.LinkedEntityId = sourceId;
                tempJunctionRecord.ShareType = 'I';
                tempJunctionRecord.Visibility = 'AllUsers';
                junctionRecords.add(tempJunctionRecord);
            }
            SFDCSecurityUtils.insertProxy(junctionRecords);
        }

        private void processStatementResults(String sourceRecordId, List<Messaging.SendEmailError> emailErrors) {
            this.statementResults.put(sourceRecordId, new StatementResult(emailErrors));
        }

        private void processStatementResults(Boolean isSuccess, Sobject sourceRecord, String errorMessage) {
            this.statementResults.put(
                sourceRecord.Id,
                new StatementResult(
                    isSuccess,
                    sourceRecord.Id,
                    (String) sourceRecord.get('Name'),
                    errorMessage
                )
            );
        }

        // returns a Map(page_name -> parial_url)
        // example: 
        //      input: Set('MyPageName')
        //      output: Map('MyPageName' -> '/apex/c__MyPageName')
        private Map<String,String> buildPartialUrlLookup(Set<String> pageNames) {
            // build a Map(page_name -> page_name_space)
            Map<String,String> pageNameSpaces = new Map<String,String>();
            for (ApexPage page : FinancialSuiteUtils.getApexPages(pageNames)) {
                // In case of duplicate page names:
                // FinancialSuiteUtils.getApexPages sorts null namespaces
                // last, so we always end up with the users pages in the map.
                pageNameSpaces.put(page.Name, page.NameSpacePrefix);
            }
            
            // build a Map(page_name -> partial_url)
            Map<String, String> urlLookup = new Map<String, String>();
            for (String pageName : pageNames) {
                // get the namespace for page
                // can be in this package, unpackaged, or from another package
                String ns = pageNameSpaces.get(pageName);
                ns = String.isBlank(ns) ? 'c__' : ns + '__';
                // combine parts into partial url
                String partialUrl = (GlobalVariables.APEX_URL_PATH + ns + pageName).toLowerCase();
                // add it to the url lookup table
                urlLookup.put(pageName, partialUrl);
            }

            return urlLookup;
        }

    }

    public with sharing class Statement {
        private StatementType stType;
        private SObjectType sourceType;
        private Id ledgerId;
        public SObject source {get; private set;}
        public Id customerId {get; set;}
        public String customer {get; set;}
        public String sourceName {get; set;}
        public String proprietaryBillNmb {get; set;}
        public String urlPDF {get; set;}
        public String emailTemplate {get; set;}
        public Contact recipient {get; set;}
        public List<String> ccAddressesList {get; set;}
        public OrgWideEmailAddress owa {get; set;}
        public Billing_Format__c pdfFormat {get; set;}
        public String customUrlParam1 {get; set;}
        public String customUrlParam2 {get; set;}
        public Map<String, String> customUrlParams { get; set; }
        public String customStatementPdfName {get; set;}
        public String currencyIsoCode {get; set;}
        public CustomEmailTemplate userDefinedTemplate {get; set;}
        public List<AbstractStatementManager.CustomEmailAttachment> customEmailAttachments {get; set;}
        public Boolean isAltPayorIncluded {get; set;}

        public Statement(SObject source,
            Billing_Format__c pdfFormat,
            String urlPDF,
            EmailTemplate template,
            StatementType stType,
            Id ledgerId,
            String currencyIsoCode) {

            this.source = source;
            this.pdfFormat = pdfFormat;
            this.stType = stType;
            this.ledgerId = ledgerId;
            this.currencyIsoCode = currencyIsoCode;
            this.sourceType = source.getSObjectType();
            this.urlPDF = urlPDF;
            this.emailTemplate = template.Id;
            this.recipient = (Contact) source.getSObject('Billing_Contact__r');
            this.customerId = (stType == StatementType.BILLING) ? (Id) source.get('Customer__c') : source.Id;
            this.customer = (stType == StatementType.BILLING) ? (String) source.getSObject('Customer__r').get('Name') : '';
            this.sourceName = (String) source.get('Name');
            this.proprietaryBillNmb = (stType != StatementType.BILLING) ? null : (String) source.get('Proprietary_Billing_Number__c');
            this.owa = getOrgWideEmailAddressFromPDF();
            this.isAltPayorIncluded = true;
        }

        /**********************
        * Security review note:
        * URL Redirection Attack issue related to the URL in the method below is false positive
        * because the code maintains control of the host by prepending '/apex/' + user_data
        * See FinancialSuiteUtils.getFullVFPageUrl() method for details
        * *********************/
        public Blob getPDF() {
            Blob result;

            Pagereference pageRef = new Pagereference(this.urlPDF);
            if (sourceType == Billing__c.SObjectType) {
                pageRef.getParameters().put(AbstractStatementManager.URL_PARAM_ID, source.Id);
                pageRef.getParameters().put(AbstractStatementManager.URL_PARAM_SORT, getSortField());
            }
            else if (sourceType == Account.SObjectType && stType == StatementType.ACTIVITY) {
                pageRef.getParameters().put(AbstractStatementManager.URL_PARAM_ID, source.Id);
                pageRef.getParameters().put('formatId', pdfFormat.Id);
                if (customUrlParams != null) {
                    parseCustomUrlParamMap(pageRef);
                } else {
                    setCustomUrlParams(pageRef);
                }
                pageRef.getParameters().put('reportType', 'activity');
                pageRef.getParameters().put('ledgerId', ledgerId);
                pageRef.getParameters().put('currencyIsoCode', currencyIsoCode);
            }
            else if (sourceType == Account.SObjectType && stType == StatementType.OUTSTANDING) {
                pageRef.getParameters().put(AbstractStatementManager.URL_PARAM_ID, source.Id);
                pageRef.getParameters().put('formatId', pdfFormat.Id);
                pageRef.getParameters().put('reportType', 'outstanding');
                pageRef.getParameters().put('ledgerId', ledgerId);
                pageRef.getParameters().put('currencyIsoCode', currencyIsoCode);
                if (customUrlParams != null) {
                    parseCustomUrlParamMap(pageRef);
                } else {
                    setCustomUrlParams(pageRef);
                }
            }
            pageRef.setRedirect(true);
            result = (Test.isRunningTest()) ? Blob.valueOf('test') : pageRef.getContentAsPDF();
            return result;
        }

        public String getSortField() {
            String result;
            if (source.get('Billing_Format__c') != NULL) {
                result =
                    source.getSObject('Billing_Format__r').get('Sort_Field__c') != NULL
                        ? ((String) source.getSObject('Billing_Format__r').get('Sort_Field__c'))
                        : '';
            }
            return result;
        }

        public ContentVersion getFile(Blob pdf) {
            return new ContentVersion(
                ContentDocumentId = NULL,
                Title = getStatementPDFName(stType),
                PathOnClient = getStatementPDFName(stType),
                VersionData = pdf
            );
        }

        private OrgWideEmailAddress getOrgWideEmailAddressFromPDF() {
            OrgWideEmailAddress result;
            if (pdfFormat != NULL
                    && !String.isBlank(pdfFormat.Org_Wide_Email_Address__c)
                    && FinancialSuiteUtils.orgWideEmailAddressMapByAddress.containsKey(pdfFormat.Org_Wide_Email_Address__c)) {

                result = FinancialSuiteUtils.orgWideEmailAddressMapByAddress.get(pdfFormat.Org_Wide_Email_Address__c);
            }
            return result;
        }

        private String getDayString() {
            if (String.isNotBlank(customUrlParam2)) {
                return Date.valueOf(customUrlParam2).format();
            }
            if (customUrlParams != null && customUrlParams.containsKey('endDate') && String.isNotBlank(customUrlParams.get('endDate'))) {
                return Date.valueOf(customUrlParams.get('endDate')).format();
            }

            return System.today().format();
        }

        @TestVisible
        private String getStatementPDFName(AbstractStatementManager.StatementType stType) {
            String dayString = getDayString();
            String stateTypeName = stType == statementType.ACTIVITY ? ACTIVITY_STATEMENT_PDF_NAME_PREFIX :
                                   stType == statementType.BILLING ? BILLING_STATEMENT_PDF_NAME_PREFIX : 
                                   CUSTOMER_STATEMENT_PDF_NAME_PREFIX ;

            //customerStatementPdf name is set for Activity and Outstanding statements in BillingStatementManager
            if (String.isBlank(customStatementPdfName)) {
    
                if (proprietaryBillNmb != NULL) {
                    sourceName = proprietaryBillNmb;
                }

                switch on stType {
                    when BILLING{
                        //for billing PDFs use standard formatting
                        return AbstractStatementManager.formatFileName(customer, stateTypeName, sourceName );
                    } 
                    when else{
                        //if customerStatementPdf is not set then use the original default
                        if (customer.length() > AbstractStatementManager.CUSTOMER_NAME_LENGTH_LIMIT) {
                            customer = customer.substring(0, AbstractStatementManager.CUSTOMER_NAME_LENGTH_LIMIT);
                        }
                        return customer + sourceName + stateTypeName + dayString + PDF_EXTENSION;
                    }
                }

            }
            else {
                return customStatementPdfName;
            }
        }

        public Messaging.SingleEmailMessage getEmail(Blob pdf) {
            //Mailing
            Messaging.SingleEmailMessage mail;
            Boolean useCustomTemplate = false;

            if (userDefinedTemplate != NULL && userDefinedTemplate.isCustomUserInput) {
                useCustomTemplate = true;
            }
            try {
                mail = new Messaging.SingleEmailMessage();

                // Sending to billing contact takes precedence
                if (recipient != NULL && recipient.Email != NULL) {
                    if (useCustomTemplate) {
                        mail.setSubject(userDefinedTemplate.emailSubject);
                        mail.setEntityAttachments(userDefinedTemplate.emailAttachmentIds);
                        if (userDefinedTemplate.isHTML) {
                            mail.setHtmlBody(userDefinedTemplate.emailBody);
                        }
                        else {
                            mail.setPlainTextBody(userDefinedTemplate.emailBody);
                        }
                    }
                    else {
                        mail.setTemplateID(emailTemplate);
                    }

                    mail.setTargetObjectId(recipient.Id);
                    mail.setWhatId(source.Id);

                    if (ccAddressesList != NULL && !ccAddressesList.isEmpty()) {
                        mail.setCcAddresses(ccAddressesList);
                    }
                    mail.setSaveAsActivity(true);
                }

                if (owa != NULL) {
                    mail.setOrgWideEmailAddressId(owa.Id);
                }

                mail.setBccSender(false);
                mail.setUseSignature(false);

                List<Messaging.EmailFileAttachment> emailFileAttachments = new List<Messaging.EmailFileAttachment>();
                //Main PDF attachment
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setFileName(getStatementPDFName(stType));
                efa.setBody(pdf);
                emailFileAttachments.add(efa);
                //Custom email attachments
                if (customEmailAttachments != NULL && !customEmailAttachments.isEmpty()) {
                    for (AbstractStatementManager.CustomEmailAttachment eachFile : customEmailAttachments) {
                        if (eachFile.getIsUploaded()) {
                            Messaging.EmailFileAttachment tempEFA = new Messaging.EmailFileAttachment();
                            tempEFA.setFileName(eachFile.fileName);
                            tempEFA.setBody(eachFile.fileBody);
                            emailFileAttachments.add(tempEFA);
                        }
                    }
                }

                mail.setFileAttachments(emailFileAttachments);

                if (sourceType == Billing__c.SObjectType
                        && source.get('Billing_Format__c') != NULL
                        && source.getSObject('Billing_Format__r').get('ReplyTo_Email__c') != NULL) {

                    mail.setReplyTo((String) source.getSObject('Billing_Format__r').get('ReplyTo_Email__c'));
                }

                if (sourceType == Account.SObjectType
                        && source.get('Outstanding_Statement_Format__c') != NULL
                        && source.getSObject('Outstanding_Statement_Format__r').get('ReplyTo_Email__c') != NULL) {

                    mail.setReplyTo((String) source.getSObject('Outstanding_Statement_Format__r').get('ReplyTo_Email__c'));
                } else if (sourceType == Account.SObjectType
                        && source.get('Activity_Statement_Format__c') != NULL
                        && source.getSObject('Activity_Statement_Format__r').get('ReplyTo_Email__c') != NULL) {

                    mail.setReplyTo((String) source.getSObject('Activity_Statement_Format__r').get('ReplyTo_Email__c'));
                } else if (sourceType == Account.SObjectType
                        && source.get('Outstanding_Statement_Format__c') == NULL && stType == StatementType.OUTSTANDING) {
                    ID defLedger = [SELECT ID, Default_Ledger__c FROM Accounting_Settings__c].Default_Ledger__c;
                    String replyToEmail = [SELECT Id, Billing_Outstanding_Statement_Format__r.ReplyTo_Email__c FROM Ledger__c WHERE Id =: defLedger].Billing_Outstanding_Statement_Format__r.ReplyTo_Email__c;
                    mail.setReplyTo((String)replyToEmail);
                } else if (sourceType == Account.SObjectType
                        && source.get('Activity_Statement_Format__c') == NULL && stType == StatementType.ACTIVITY) {
                    ID defLedger = [SELECT ID, Default_Ledger__c FROM Accounting_Settings__c].Default_Ledger__c;
                    String replyToEmail = [SELECT Id, Billing_Activity_Statement_Format__r.ReplyTo_Email__c FROM Ledger__c WHERE Id =: defLedger].Billing_Activity_Statement_Format__r.ReplyTo_Email__c;
                    mail.setReplyTo((String)replyToEmail);
                }
            }
            catch (Exception ex) {
                throw new StatementPdfException(ex.getMessage());
            }

            return mail;
        }

        //setters
        public Statement setCustomUrlParams(Map<String, String> customUrlParams) {
            this.customUrlParams = customUrlParams;
            return this;
        }

        private void parseCustomUrlParamMap(PageReference pageRef) {
            for (String key : customUrlParams.keySet()) {
                if (String.isNotBlank(customUrlParams.get(key))) {
                    pageRef.getParameters().put(key, customUrlParams.get(key));
                }
            }
        }

        private void setCustomUrlParams(PageReference pageRef) {
            if (!String.isBlank(customUrlParam1)) {
                pageRef.getParameters().put('startDate', customUrlParam1);
            }
            if (!String.isBlank(customUrlParam2)) {
                pageRef.getParameters().put('endDate', customUrlParam2);
            }
            pageRef.getParameters().put('includeAltPayor', String.valueOf(isAltPayorIncluded));
        }

    }

    public with sharing class StatementResult {
        public Boolean isSuccess;
        public String sourceId;
        public String sourceName;
        public List<String> messages;

        public StatementResult(Boolean isSuccess, Id sourceId, String sourceName, List<String> messages) {
            this.isSuccess = isSuccess;
            this.sourceId = sourceId;
            this.sourceName = sourceName;
            this.messages = messages;
        }

        public StatementResult(Boolean isSuccess, Id sourceId, String sourceName, String message) {
            this(isSuccess, sourceId, sourceName, new List<String> {message});
        }

        public StatementResult(List<Messaging.SendEmailError> errs) {
            if (errs != NULL && !errs.isEmpty()) {
                this.isSuccess = false;
                this.messages = new List<String>();
                for (Messaging.SendEmailError err : errs) {
                    this.messages.add(err.getMessage());
                }
            }
        }
    }

    public with sharing class CustomEmailTemplate {
        private Id storedTemplateId;
        private Id billingContactId;
        private Id sourceRecordId;
        private String originalEmailSubject;
        private String originalEmailBody;

        public String emailSubject {get; set;}
        public String emailBody {get; set;}
        public Boolean isHTML {get; set;}
        public List<String> emailAttachmentIds {get; set;}
        public Boolean isCustomUserInput {get; set;}

        public CustomEmailTemplate(EmailTemplate storedTemplate, Id billingContactId, Id sourceRecordId) {
            this.storedTemplateId = storedTemplate.Id;
            this.billingContactId = billingContactId;
            this.sourceRecordId = sourceRecordId;
            this.isCustomUserInput = false;
            this.isHTML = (storedTemplate.TemplateType.equalsIgnoreCase('Text')) ? false : true;
            if (storedTemplateId != NULL && billingContactId != NULL && sourceRecordId != NULL) {
                setSubjectAndBodyFromTemplate();
            }
        }

        private void setSubjectAndBodyFromTemplate() {
            Messaging.SingleEmailMessage email =
                Messaging.renderStoredEmailTemplate(storedTemplateId, billingContactId, sourceRecordId);
            emailSubject = originalEmailSubject = email.getSubject();
            emailAttachmentIds = email.getEntityAttachments();
            if (String.isBlank(email.getHtmlBody())) {
                emailBody = originalEmailBody = email.getPlainTextBody();
            }
            else {
                emailBody = originalEmailBody = email.getHtmlBody();
            }
        }

        public Boolean checkTemplateChanged() {
            this.isCustomUserInput = false;
            if (emailSubject != originalEmailSubject
                /*|| emailBody.replaceAll('<[^>]+>','') != originalEmailBody.replaceAll('<[^>]+>','')*/
                || emailBody != originalEmailBody) {

                isCustomUserInput = true;
            }
            return isCustomUserInput;
        }
    }

    public with sharing class CustomEmailAttachment {
        public String fileId {get; set;}
        public String fileName {get; set;}
        public Integer fileSize {get; set;}
        public transient Blob fileBody {get; set;}
        public Boolean isLinkedWithEntity {get; set;}

        public Boolean getIsUploaded() {
            return !String.isBlank(fileName) && fileBody != NULL;
        }
    }

    public with sharing class RemoteActionResult {
        public Boolean isValidContact {get; set;}
        public String errorMessage {get; set;}
        public CustomEmailTemplate template {get; set;}
    }

    public enum StatementType {
        BILLING,
        OUTSTANDING,
        ACTIVITY
    }

    public enum StatementBase {
        BILLING,
        CUSTOMER
    }

    public class StatementPdfException extends Exception {}

}