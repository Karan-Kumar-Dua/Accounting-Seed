public with sharing class BillingStatementManager extends AbstractStatementManager {
   
    public static final String NO_OUTSTANDING_PDF_FORMAT_DEFINED_ERROR = Label.ERR_NO_OUTSTANDING_PDF_FORMAT_DEFINED;
    public static final String NO_ACTIVITY_PDF_FORMAT_DEFINED_ERROR = Label.ERR_NO_ACTIVITY_PDF_FORMAT_DEFINED;
    private static final String NO_EMAIL_TEMPLATE_ERROR = Label.ERR_BILLING_FORMAT_NO_EMAIL_TEMPLATE;

    public AbstractStatementManager.StatementSet outstandingStatementManager {get; set;}
    public AbstractStatementManager.StatementSet activityStatementManager {get; set;}

    public Account acct {get; set;}
    public Billing__c activityBill {get; set;}
    public Billing__c outstandingBill {get; set;}
    public String selectedTab {get; set;}
    public Boolean activityCCUser {get; set;}
    public Boolean outstandingCCUser {get; set;}
    public String activityCCAddresses {get; set;}
    public String outstandingCCAddresses {get; set;}
    public Boolean isActivityFormatError {get; private set;}
    public Boolean isOutstandingFormatError {get; private set;}
    public Boolean showIframe {get; set;}
    public Account outstandingAccount {get; set;}
    public Account activityAccount {get; set;}
    public String activityPDFName {get; private set;}
    public String outstandingPDFName {get; private set;}
    public Billing_Format__c activityPdfFormat {get; private set;}
    public Billing_Format__c outstandingPdfFormat {get; private set;}
    public Boolean showPage {get; private set;}
    public List<SelectOption> availableCurrencies {get; set;}
    public Account proxyActivityPdfFormat {get; set;}
    public Account proxyOutstandingPdfFormat {get; set;}
    public String activitySelectedOrgWideEmailAddress {get; set;}
    public String outstandingSelectedOrgWideEmailAddress {get; set;}
    public Boolean isAltPayorIncluded {get; set;}

    public BillingStatementManager(ApexPages.StandardController controller) {
        try {
            this.showPage = true;
            this.selectedTab = 'outstanding';
            this.isActivityFormatError = false;
            this.isOutstandingFormatError = false;
            this.activityCCUser = false;
            this.outstandingCCUser = false;
            this.showIframe = false;
            this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.acct = DomainUtils.getAccountsBySelectedAccounts(new List<Account>{(Account) controller.getRecord()})[0];
            this.outstandingAccount = new Account();
            this.activityAccount = new Account();
            this.activityBill = new Billing__c(Date__c = System.today() - 60, Due_Date2__c = System.today());
            this.outstandingBill = new Billing__c();
            this.proxyActivityPdfFormat = new Account();
            this.proxyOutstandingPdfFormat = new Account();
            activityBill.Ledger__c = outstandingBill.Ledger__c = LedgerHandler.getLedgerId();

            this.outstandingStatementManager = new AbstractStatementManager.StatementSet(
                new List<Account>{this.acct},
                AbstractStatementManager.StatementType.OUTSTANDING,
                NULL
            );

            if (outstandingStatementManager.statements[0].pdfFormat == NULL) {
                isOutstandingFormatError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_OUTSTANDING_PDF_FORMAT_DEFINED_ERROR));
            }
            else {
                this.outstandingPDFName = outstandingStatementManager.statements[0].urlPDF;
                this.outstandingPdfFormat = outstandingStatementManager.statements[0].pdfFormat;
                this.proxyOutstandingPdfFormat.Outstanding_Statement_Format__c = this.outstandingPdfFormat.Id;
            }

            this.activityStatementManager = new AbstractStatementManager.StatementSet(
                new List<Account>{this.acct},
                AbstractStatementManager.StatementType.ACTIVITY,
                NULL
            );

            if (activityStatementManager.statements[0].pdfFormat == NULL) {
                isActivityFormatError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_ACTIVITY_PDF_FORMAT_DEFINED_ERROR));
            }
            else {
                this.activityPDFName = activityStatementManager.statements[0].urlPDF;
                this.activityPdfFormat = activityStatementManager.statements[0].pdfFormat;
                this.proxyActivityPdfFormat.Activity_Statement_Format__c = this.activityPdfFormat.Id;
            }

            if (isMultiCurrencyEnabled) {
                activityBill.put('CurrencyIsoCode', activityStatementManager.statements[0].currencyIsoCode);
                outstandingBill.put('CurrencyIsoCode', outstandingStatementManager.statements[0].currencyIsoCode);
                availableCurrencies = MultiCurrencyHandler.getAllCurrenciesSelectOptions();
            }

            outstandingAccount.Billing_Contact__c = activityAccount.Billing_Contact__c = acct.Billing_Contact__c;
            outstandingAccount.Billing_Contact__r = activityAccount.Billing_Contact__r = acct.Billing_Contact__r;
            activityCCAddresses = outstandingCCAddresses = getCCAddresses(acct.Id);
            getOrgWideEmailSelectOptions(NULL);
            setStatementSelectedOrgWideEmailAddress();

            this.isAltPayorIncluded = true;
            this.showIframe = true;
        }
        catch (Exception ex) {
            showPage = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
    }

    public PageReference changeOutstandingPDFFormat() {
        outstandingStatementManager.setDefaultPdfByPdfId(proxyOutstandingPdfFormat.Outstanding_Statement_Format__c);
        if (outstandingStatementManager.statements[0].pdfFormat == NULL) {
            isOutstandingFormatError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_OUTSTANDING_PDF_FORMAT_DEFINED_ERROR));
        }
        else {
            outstandingPDFName = outstandingStatementManager.statements[0].urlPDF;
            outstandingPdfFormat = outstandingStatementManager.statements[0].pdfFormat;
        }
        setOutstandingStatementSelectedOrgWideEmailAddress();
        updateOSEmailTemplate();
        return NULL;
    }

    public PageReference changeActivityPDFFormat() {
        activityStatementManager.setDefaultPdfByPdfId(proxyActivityPdfFormat.Activity_Statement_Format__c);
        if (activityStatementManager.statements[0].pdfFormat == NULL) {
            isActivityFormatError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_ACTIVITY_PDF_FORMAT_DEFINED_ERROR));
        }
        else {
            activityPDFName = activityStatementManager.statements[0].urlPDF;
            activityPdfFormat = activityStatementManager.statements[0].pdfFormat;
        }
        setActivityStatementSelectedOrgWideEmailAddress();
        updateASEmailTemplate();
        return NULL;
    }

    public PageReference changeOutstandingLedger() {
        outstandingStatementManager.setLedgerBySelectedLedgerId(outstandingBill.Ledger__c);
        updateOSCurrencyWithOSFormat();
        return NULL;
    }

    private void updateOSEmailTemplate(){
        outstandingStatementManager.custEmailTempl = new CustomEmailTemplate(
            outstandingStatementManager.sourceToTemplate.get(acct.Id),
                    (Id)outstandingAccount.Billing_Contact__c,
                    acct.Id
                );
    }
    
    private void updateOSCurrencyWithOSFormat(){
        Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(outstandingBill.Ledger__c);
        
        if (isMultiCurrencyEnabled) {
            outstandingBill.put('CurrencyIsoCode',(String) ledger.get('CurrencyIsoCode'));
            changeOutstandingCurrencyIsoCode();
        }

        proxyOutstandingPdfFormat.Outstanding_Statement_Format__c = (Id)ledger.Billing_Outstanding_Statement_Format__c;
        changeOutstandingPDFFormat();
        
    }
    public PageReference changeActivityLedger() {
        activityStatementManager.setLedgerBySelectedLedgerId(activityBill.Ledger__c);
        updateASCurrencyWithASFormat();
        return NULL;
    }

    private void updateASEmailTemplate(){
        activityStatementManager.custEmailTempl = new CustomEmailTemplate(
            activityStatementManager.sourceToTemplate.get(acct.Id),
                    (Id)activityAccount.Billing_Contact__c,
                    acct.Id
                );
    }

    private void updateASCurrencyWithASFormat(){
        Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(activityBill.Ledger__c);
        
        if (isMultiCurrencyEnabled) {
            activityBill.put('CurrencyIsoCode',(String) ledger.get('CurrencyIsoCode'));
            changeActivityCurrencyIsoCode();
        }
        
        proxyActivityPdfFormat.Activity_Statement_Format__c = (Id)ledger.Billing_Activity_Statement_Format__c;
        changeActivityPDFFormat();
    }

    public PageReference changeActivityCurrencyIsoCode() {
        activityStatementManager.setCurrencyBySelectedCurrencyIsoCode((String) activityBill.get('CurrencyIsoCode'));
        return NULL;
    }

    public PageReference changeOutstandingCurrencyIsoCode() {
        outstandingStatementManager.setCurrencyBySelectedCurrencyIsoCode((String) outstandingBill.get('CurrencyIsoCode'));
        return NULL;
    }

    public List<SelectOption> getAllLedgers() {
        return LedgerHandler.getInstanceWithSharing().getTransactionalLedgerSelectOptions();
    }

    public Boolean getIsValidationError() {
        return ApexPages.hasMessages() && ApexPages.getMessages()[0].getDetail().contains(SObjectActions.REQUIRED_FIELD_ERROR)
            ? true
            : false;
    }

    public String getActivityStartDate() {
        return String.valueOf(activityBill.Date__c.year()) +
                '-' +
                FinancialSuiteUtils.leftPad(String.valueOf(activityBill.Date__c.month()), 1) +
                '-' +
                FinancialSuiteUtils.leftPad(String.valueOf(activityBill.Date__c.day()), 1);
    }
    
    public String getActivityEndDate() {
        return String.valueOf(activityBill.Due_Date2__c.year()) +
                '-' +
                FinancialSuiteUtils.leftPad(String.valueOf(activityBill.Due_Date2__c.month()), 1) +
                '-' +
                FinancialSuiteUtils.leftPad(String.valueOf(activityBill.Due_Date2__c.day()), 1);
    }

    public String getOutstandingEndDate() {
        return String.valueOf(generateStatementAsOfProxyRecord.Discount_Due_Date__c.year()) +
            '-' +
            FinancialSuiteUtils.leftPad(String.valueOf(generateStatementAsOfProxyRecord.Discount_Due_Date__c.month()), 1) +
            '-' +
            FinancialSuiteUtils.leftPad(String.valueOf(generateStatementAsOfProxyRecord.Discount_Due_Date__c.day()), 1);
    }

    public PageReference saveAttach() {
        try {
            setCustomStatementName();
            processCustomEmailAttachments();
            Map<Id, StatementResult> results = getStatementManager().savePDFs(false);
            if (processResults(results)) {
                bindFilesWithSourceRecord(acct.Id);
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, Label.COMMON_ATTATCHMENT_HAS_BEEN_SAVED));
            }
            else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, results.values()[0].messages[0]));
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }

        return NULL;
    }

    public PageReference saveAndEmail() {
        try {
            List<String> ccAddressesList = new List<String>();
            if ((selectedTab == 'activity' && activityCCUser) || (selectedTab == 'outstanding' && outstandingCCUser)) {
                ccAddressesList.add(UserInfo.getUserEmail());
            }

            if (selectedTab == 'outstanding') {
                selectedOrgWideEmailAddress = outstandingSelectedOrgWideEmailAddress;
                if (!String.isBlank(outstandingCCAddresses)) {
                    ccAddressesList.addAll(outstandingCCAddresses.split(','));
                }
            }
            else if (selectedTab == 'activity') {
                selectedOrgWideEmailAddress = activitySelectedOrgWideEmailAddress;
                if (!String.isBlank(activityCCAddresses)) {
                    ccAddressesList.addAll(activityCCAddresses.split(','));
                }
            }

            StatementSet genericStatementManager = getStatementManager();
            if (!String.isBlank(selectedOrgWideEmailAddress)) {
                genericStatementManager.statements[0].owa = orgWideEmailMap.get(selectedOrgWideEmailAddress);
            }
            genericStatementManager.statements[0].ccAddressesList = ccAddressesList;
            setCustomStatementName();
            //if user did some changes in email subject or body
            //this changed data will be used for a sent email
            genericStatementManager.custEmailTempl.checkTemplateChanged();
            if (genericStatementManager.custEmailTempl.isCustomUserInput) {
                genericStatementManager.statements[0].userDefinedTemplate = genericStatementManager.custEmailTempl;
            }

            //set custom file attachments for a sent email
            processCustomEmailAttachments();
            genericStatementManager.statements[0].customEmailAttachments = customEmailAttachments;

            Map<Id, StatementResult> results = genericStatementManager.savePDFs(true);
            if (processResults(results)) {
                bindFilesWithSourceRecord(acct.Id);
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.CONFIRM,
                        EMAIL_SENT_SUCCESS + genericStatementManager.statements[0].recipient.Email
                    )
                );
            }
            else {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        results.values()[0].messages[0]
                    )
                );
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return NULL;
    }

    private void setStatementSelectedOrgWideEmailAddress() {
        setActivityStatementSelectedOrgWideEmailAddress();
        setOutstandingStatementSelectedOrgWideEmailAddress();
    }

    private void setActivityStatementSelectedOrgWideEmailAddress() {
        activitySelectedOrgWideEmailAddress = selectedOrgWideEmailAddress;
        if (!String.isBlank(activityPdfFormat.Org_Wide_Email_Address__c) && fromAddressPicklistEnabled) {
            activitySelectedOrgWideEmailAddress = getOrgWideEmailAddressId(activityPdfFormat.Org_Wide_Email_Address__c);
        }
    }

    private void setOutstandingStatementSelectedOrgWideEmailAddress() {
        outstandingSelectedOrgWideEmailAddress = selectedOrgWideEmailAddress;
        if (!String.isBlank(outstandingPdfFormat.Org_Wide_Email_Address__c) && fromAddressPicklistEnabled) {
            outstandingSelectedOrgWideEmailAddress = getOrgWideEmailAddressId(outstandingPdfFormat.Org_Wide_Email_Address__c);
        }
    }

    private String getOrgWideEmailAddressId(String orgWideEmailAddress) {
        String orgWideEmailAddressId;
        if (!orgWideEmailSelectOptions.isEmpty()) {
            for (SelectOption option : orgWideEmailSelectOptions) {
                if (option.getLabel().contains(orgWideEmailAddress)) {
                    orgWideEmailAddressId = option.getValue();
                }
            }
        }
        return orgWideEmailAddressId;
    }

    private AbstractStatementManager.StatementSet getStatementManager() {
        AbstractStatementManager.StatementSet result;
        if (selectedTab == 'activity') {
            result = activityStatementManager;
            //add activity Start & End Dates to PDF URL
            if (!result.statements.isEmpty()) {
                result.statements[0].customUrlParam1 = getActivityStartDate();
                result.statements[0].customUrlParam2 = getActivityEndDate();
                //add "Include Alternate Payor" value set by user on UI
                result.statements[0].isAltPayorIncluded = this.isAltPayorIncluded;
            }
        }
        else if (selectedTab == 'outstanding') {
            result = outstandingStatementManager;
            if (!result.statements.isEmpty()) {
                result.statements[0].customUrlParam2 = getOutstandingEndDate();
            }
        }
        return result;
    }

    private void setCustomStatementName() {
        if(acct.Name.length()> 212) {
            acct.Name = acct.Name.substring(0, 212);
        }

        String dayString = generateStatementAsOfProxyRecord.Discount_Due_Date__c.format();

        String statementName = acct.Name + '_' +
            selectedTab.capitalize() +
                '_Statement_' + dayString +'.pdf';

        getStatementManager().statements[0].customStatementPdfName = statementName;
    }
    
    // disable email button if appropriate selections have not been made.
    public Boolean getDisableOutstandingEmail() {
        return
            (outstandingStatementManager != NULL &&
                String.isBlank(outstandingStatementManager.statements[0].emailTemplate))
                || outstandingAccount.Billing_Contact__c == NULL
                || outstandingAccount.Billing_Contact__r.Email == NULL
                    ? true : false;
    }

    public Boolean getDisableActivityEmail() {
        return
            (activityStatementManager != NULL &&
                String.isBlank(activityStatementManager.statements[0].emailTemplate))
                || activityAccount.Billing_Contact__c == NULL
                || activityAccount.Billing_Contact__r.Email == NULL
                    ? true : false;
    }

    public PageReference setActivityContact() {
        return setContact(activityAccount, activityStatementManager);
    }

    public PageReference setOutstandingContact() {
        return setContact(outstandingAccount, outstandingStatementManager);
    }

    private PageReference setContact(Account xAccount, StatementSet statementManager) {
        try {
            if (xAccount.Billing_Contact__c != NULL) {
                List<Contact> recipients = DomainUtils.getContactById(new Set<Id>{xAccount.Billing_Contact__c});
                if (recipients.isEmpty()) {
                    throw new AbstractStatementManager.StatementPdfException(Label.COMMON_CONTACT_IS_INVALID);
                }
                if (recipients[0].Email == NULL) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_EMAIL_ERROR));
                }
                else {
                    //refresh Contact
                    statementManager.statements[0].recipient = recipients[0];
                    //refresh template
                    xAccount.Id = acct.Id;
                    xAccount.Billing_Contact__r = recipients[0];
                    statementManager.custEmailTempl = new CustomEmailTemplate(
                        statementManager.sourceToTemplate.get(xAccount.Id),
                        statementManager.statements[0].recipient.Id,
                        xAccount.Id
                    );
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }

        return NULL;
    }

    @RemoteAction
    public static AbstractStatementManager.RemoteActionResult setContactRemote( String accountId,
                                                                                String contactId,
                                                                                String stType,
                                                                                String ledgerId) {

        AbstractStatementManager.RemoteActionResult result = new AbstractStatementManager.RemoteActionResult();
        if (String.isBlank(accountId) || String.isBlank(contactId)) {
            result.isValidContact = false;
            return result;
        }
        try {
            Contact theContact = DomainUtils.getContactById(new Set<Id>{contactId})[0];
            if (theContact.Email == NULL) {
                throw new AbstractStatementManager.StatementPdfException(AbstractStatementManager.NO_EMAIL_ERROR);
            }

            Account theAccount = DomainUtils.getAccountsById(new Set<Id>{accountId})[0];
            Id theBillingFormatId;
            //Set from direct lookups
            if (stType == 'activity' && theAccount.Activity_Statement_Format__c != NULL) {
                theBillingFormatId = theAccount.Activity_Statement_Format__c;
            }
            else if (stType == 'outstanding' && theAccount.Outstanding_Statement_Format__c != NULL) {
                theBillingFormatId = theAccount.Outstanding_Statement_Format__c;
            }
            //set from selected Ledger
            if (theBillingFormatId == NULL) {
                Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
                if (stType == 'activity') {
                    theBillingFormatId = ledger.Billing_Activity_Statement_Format__c;
                }
                else if (stType == 'outstanding') {
                    theBillingFormatId = ledger.Billing_Outstanding_Statement_Format__c;
                }
            }

            List<Billing_Format__c> theFormats = DomainUtils.getBillingFormatsById(new Set<Id>{theBillingFormatId});
            if (theFormats.isEmpty()) {
                throw new AbstractStatementManager.StatementPdfException(
                    (stType == 'activity')
                        ? NO_ACTIVITY_PDF_FORMAT_DEFINED_ERROR
                        : NO_OUTSTANDING_PDF_FORMAT_DEFINED_ERROR
                );
            }

            List<EmailTemplate> theTemplates = DomainUtils.getEmailTemplatesByDeveloperName(
                new Set<String>{theFormats[0].Default_Email_Template__c}
            );
            if (theTemplates.isEmpty()) {
                throw new AbstractStatementManager.StatementPdfException(NO_EMAIL_TEMPLATE_ERROR);
            }

            result.template = new CustomEmailTemplate(
                theTemplates[0],
                theContact.Id,
                theAccount.Id
            );

            result.isValidContact = true;
        }
        catch (Exception ex) {
            result.isValidContact = false;
            result.errorMessage = ex.getMessage();
        }

        return result;
    }

}