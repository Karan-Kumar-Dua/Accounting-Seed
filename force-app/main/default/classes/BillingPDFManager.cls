public with sharing class BillingPDFManager extends AbstractStatementManager {

    public static final String NO_BILLING_FORMAT_ERROR = Label.ERR_NO_BILLING_FORMAT;
    public static final String NO_VF_PAGE_ERROR = Label.ERR_NO_VF_BILLING_FORMAT;
    private static final String NO_EMAIL_TEMPLATE_ERROR = Label.ERR_BILLING_FORMAT_NO_EMAIL;

    public AbstractStatementManager.StatementSet statementManager {get; set;}

    public Billing__c billing {get; private set;}
    public Boolean showPage {get; private set;}
    public Boolean showSavePdf {get; private set;}
    public Boolean showSendEmail {get; private set;}
    public String pdfName {get; private set;}
    public Boolean sendCCUser {get; set;}
    public String ccAddresses {get; set;}

    public BillingPDFManager(ApexPages.StandardController controller) {
        this.showPage = true;
        this.showSavePdf = true;
        this.showSendEmail = true;
        try {
            this.billing = DomainUtils.getBillingsBySelectedBillings(new List<SObject>{controller.getRecord()})[0];
            if (validateBilling()) {
                this.statementManager =
                    new AbstractStatementManager.StatementSet(
                        new List<Billing__c>{billing},
                        AbstractStatementManager.StatementType.BILLING,
                        NULL
                    );

                this.pdfName = statementManager.statements[0].urlPDF;
                this.ccAddresses = getCCAddresses(billing.Customer__c);
                getOrgWideEmailSelectOptions(billing.Billing_Format__r.Org_Wide_Email_Address__c);
            }
        }
        catch (Exception ex) {
            showPage = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
    }

    private Boolean validateBilling() {
        if (this.billing.Billing_Format__r == NULL) {
            showPage = false;
            showSavePdf = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_BILLING_FORMAT_ERROR));
        }
        else if (this.billing.Billing_Format__r.Visualforce_PDF_Page__c == NULL) {
            showPage = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_VF_PAGE_ERROR));
        }
        else if (this.billing.Billing_Format__r.Default_Email_Template__c == NULL) {
            showPage = false;
            showSendEmail = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_EMAIL_TEMPLATE_ERROR));
        }

        if (this.billing.Billing_Contact__c == NULL || this.billing.Billing_Contact__r.Email == NULL) {
            showSendEmail = false;
        }

        return showPage && showSavePdf;
    }

    public PageReference setContact() {
        try {
            if (billing.Billing_Contact__c != NULL) {
                List<Contact> recipients = DomainUtils.getContactById(new Set<Id>{billing.Billing_Contact__c});
                if (recipients.isEmpty()) {
                    throw new AbstractStatementManager.StatementPdfException(Label.COMMON_CONTACT_IS_INVALID);
                }
                if (recipients[0].Email == NULL) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_EMAIL_ERROR));
                    this.showSendEmail = false;
                }
                else {
                    //refresh Contact
                    statementManager.statements[0].recipient = recipients[0];
                    //refresh template
                    statementManager.custEmailTempl = new CustomEmailTemplate(
                        statementManager.sourceToTemplate.get(billing.Id),
                        statementManager.statements[0].recipient.Id,
                        billing.Id
                    );
                    this.showSendEmail = true;
                }
            }
            else {
                this.showSendEmail = false;
            }
        }
        catch (Exception ex) {
            this.showSendEmail = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
        return NULL;
    }

    @RemoteAction
    public static AbstractStatementManager.RemoteActionResult setContactRemote(String billingId, String contactId) {
        AbstractStatementManager.RemoteActionResult result = new AbstractStatementManager.RemoteActionResult();
        if (String.isBlank(billingId) || String.isBlank(contactId)) {
            result.isValidContact = false;
            return result;
        }
        try {
            Contact theContact = DomainUtils.getContactById(new Set<Id>{contactId})[0];
            if (theContact.Email == NULL) {
                throw new AbstractStatementManager.StatementPdfException(AbstractStatementManager.NO_EMAIL_ERROR);
            }

            Billing__c theBilling = DomainUtils.getBillingsById(new Set<Id>{billingId})[0];
            List<Billing_Format__c> theFormats = DomainUtils.getBillingFormatsById(new Set<Id>{theBilling.Billing_Format__c});
            if (theFormats.isEmpty()) {
                throw new AbstractStatementManager.StatementPdfException(NO_BILLING_FORMAT_ERROR);
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
                theBilling.Id
            );

            result.isValidContact = true;
        }
        catch (Exception ex) {
            result.isValidContact = false;
            result.errorMessage = ex.getMessage();
        }

        return result;
    }

    public PageReference saveAttach() {
        try {
            processCustomEmailAttachments();
            Map<Id, StatementResult> results = statementManager.savePDFs(false);
            if (processResults(results)) {
                bindFilesWithSourceRecord(billing.Id);
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
            if (!String.isBlank(ccAddresses)) {
                ccAddressesList = ccAddresses.split(',');
            }
            if (sendCCUser) {
                ccAddressesList.add(UserInfo.getUserEmail());
            }
            if (!String.isBlank(selectedOrgWideEmailAddress)) {
                statementManager.statements[0].owa = orgWideEmailMap.get(selectedOrgWideEmailAddress);
            }
            statementManager.statements[0].ccAddressesList = ccAddressesList;
            //if user did some changes in email subject or body
            //this changed data will be used for a sent email
            statementManager.custEmailTempl.checkTemplateChanged();
            if (statementManager.custEmailTempl.isCustomUserInput) {
                statementManager.statements[0].userDefinedTemplate = statementManager.custEmailTempl;
            }
            //set custom file attachments for a sent email
            processCustomEmailAttachments();
            statementManager.statements[0].customEmailAttachments = customEmailAttachments;

            Map<Id, StatementResult> results = statementManager.savePDFs(true);
            if (processResults(results)) {
                bindFilesWithSourceRecord(billing.Id);
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.CONFIRM,
                        EMAIL_SENT_SUCCESS + statementManager.statements[0].recipient.Email
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

    public String getSortField() {
        return statementManager.statements[0].getSortField();
    }

}