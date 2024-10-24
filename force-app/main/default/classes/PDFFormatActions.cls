public with sharing class PDFFormatActions {
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String VF_PAGE_ERROR = Label.ERR_VF_PAGE;
    public static final String EMAIL_TEMPLATE_ERROR = Label.ERR_EMAIL_TEMPLATE;
    public static final String AUTOMATED_EMAIL_DELIVERY_ERROR = Label.ERR_AUTOMATED_EMAIL_DELIVERY;
    public static final String OWE_ERROR = Label.ERR_OWE;
    public static final String DELETE_ERROR =
        Label.ERR_DELETE;

    public static final List<String> relatedObjectForDeleteValidation {
        get {
            relatedObjectForDeleteValidation = new List<String> {
                PACKAGE_QUALIFIER + 'Billing__c',
                PACKAGE_QUALIFIER + 'Ledger__c'
            };
            return relatedObjectForDeleteValidation;
        }
        private set;
    }

    public static void checkVFPageExists(List<Billing_Format__c> billingFormats) {
        Map<String,List<Billing_Format__c>> billingFormatMap = new Map<String,List<Billing_Format__c>>();
        
        for (Billing_Format__c bFormat : billingFormats) {
            if (billingFormatMap.containsKey(bFormat.Visualforce_PDF_Page__c)) {
                billingFormatMap.get(bFormat.Visualforce_PDF_Page__c).add(bFormat);
            }
            else {
                billingFormatMap.put(bFormat.Visualforce_PDF_Page__c, new Billing_Format__c[]{bFormat});
            }
        }
        
        for (String page : DomainUtils.getApexPagesByName(billingFormatMap.keySet())) {
            if (billingFormatMap.containsKey(page)) {
                billingFormatMap.remove(page);
            }
        }
        
        for (String key : billingFormatMap.keySet()) {
            for (Billing_Format__c bFormat : billingFormatMap.get(key)) {
                bFormat.Visualforce_PDF_Page__c.addError(VF_PAGE_ERROR);
            }
        }       
    }

    public static void setAutomatedEmailDeliveryField(List<Billing_Format__c> billingFormats) {
        for (Billing_Format__c bFormat : billingFormats) {
            if (bFormat.Automated_Email_Delivery2__c == null) {
                bFormat.Automated_Email_Delivery2__c = 'No Delivery';
            }
        }
    }

    public static void checkAutomatedEmailDeliveryField(List<Billing_Format__c> billingFormats) {
        for (Billing_Format__c bFormat : billingFormats) {
            if (bFormat.Automated_Email_Delivery2__c == null) {
                bFormat.Automated_Email_Delivery2__c.addError(AUTOMATED_EMAIL_DELIVERY_ERROR);
            }
        }
    }
    
    public static void checkEmailTemplateExists(List<Billing_Format__c> billingFormats) {
        Map<String, List<Billing_Format__c>> billingFormatMap = new Map<String, List<Billing_Format__c>>();
        
        for (Billing_Format__c bFormat : billingFormats) {
            if (billingFormatMap.containsKey(bFormat.Default_Email_Template__c)) {
                billingFormatMap.get(bFormat.Default_Email_Template__c).add(bFormat);
            }
            else {
                billingFormatMap.put(bFormat.Default_Email_Template__c, new Billing_Format__c[]{bFormat});
            }
        }
        
        for (String templateDevName : DomainUtils.getEmailTemplatesByDeveloperNameString(billingFormatMap.keySet())) {
            if (billingFormatMap.containsKey(templateDevName)) {
                billingFormatMap.remove(templateDevName);
            }
        }
        
        for (String key : billingFormatMap.keySet()) {
            for (Billing_Format__c bFormat : billingFormatMap.get(key)) {
                bFormat.Default_Email_Template__c.addError(EMAIL_TEMPLATE_ERROR);
            }
        }       
    }

    public static void validateOrgWideEmailAddress(List<Billing_Format__c> billingFormats) {
        Set<String> addressSet = getAddressList(DomainUtils.getOrgWideEmailAddress());
        for (Billing_Format__c bFormat : billingFormats) {
            if (bFormat.Org_Wide_Email_Address__c != NULL && !addressSet.contains(bFormat.Org_Wide_Email_Address__c)) {
                bFormat.Org_Wide_Email_Address__c.addError(OWE_ERROR);
            }
        }
    }

    private static Set<String> getAddressList(List<OrgWideEmailAddress> oweAddress) {
        Set<String> result = new Set<String>();
        for (OrgWideEmailAddress address : oweAddress) {
            try {
                result.add(address.Address);
            } catch (SObjectException ex) {
                // Post install script lands here. Address is not returned from DomainUtils::getOrgWideEmailAddress
                break;
            }
        }
        return result;
    }

    public static void preventDeleteIfRelatedRecordsExist(Map<Id, Billing_Format__c> oldPdfFormatMap) {
        Set<Id> pdfFormatsWithRelatedRecords = new Set<Id> ();

        for (String objName : relatedObjectForDeleteValidation) {
            if (objName == PACKAGE_QUALIFIER + 'Ledger__c') {
                List<AggregateResult> results = DomainUtils.getRelatedObjectCountByApiNameAndLookupNames(
                    oldPdfFormatMap.keySet(),
                    objName,
                    new List<String>{
                        'Billing_Activity_Statement_Format__c',
                        'Billing_Outstanding_Statement_Format__c',
                        'Default_Billing_Format__c'
                    }
                );
                for (AggregateResult result : results) {
                    if (result.get('itemCount') != 0) {
                        pdfFormatsWithRelatedRecords.add((String) result.get('Billing_Activity_Statement_Format'));
                        pdfFormatsWithRelatedRecords.add((String) result.get('Billing_Outstanding_Statement_Format'));
                        pdfFormatsWithRelatedRecords.add((String) result.get('Default_Billing_Format'));
                    }
                }
            }
            else {
                Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                    DomainUtils.getRelatedObjectCountByApiNameAndLookupName(oldPdfFormatMap.keySet(), objName, 'Billing_Format__c')
                );
                for (Id resId : results.keySet()) {
                    if (results.get(resId).get('itemCount') != 0) {
                        pdfFormatsWithRelatedRecords.add(resId);
                    }
                }
            }

        }

        if (!pdfFormatsWithRelatedRecords.isEmpty()) {
            for (Id pdfFormatId : pdfFormatsWithRelatedRecords) {
                if (oldPdfFormatMap.get(pdfFormatId) != NULL) {
                    oldPdfFormatMap.get(pdfFormatId).addError(DELETE_ERROR);
                }
            }
        }
    }

}