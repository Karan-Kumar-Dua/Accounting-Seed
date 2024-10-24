public with sharing class NavToCreateController {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;


    private static SObjectType journalEntrySOType = Journal_Entry__c.getSObjectType();
    private static SObjectType billingSOType = Billing__c.getSObjectType();
    private static SObjectType accountPayableSOType = Account_Payable__c.getSObjectType();
    private static SObjectType recurringBillingSOType = Recurring_Billing__c.getSObjectType();
    private static SObjectType recurringAccountPayableSOType = Recurring_Account_Payable__c.getSObjectType();
    private static Map<SObjectType, Set<String>> fieldsBySObjectTypes = new Map<SObjectType, Set<String>>{
            journalEntrySOType => new Set<String>{
                    PACKAGE_QUALIFIER + 'Journal_Date__c'
            },
            billingSOType => new Set<String>{
                    PACKAGE_QUALIFIER + 'Date__c'
            },
            accountPayableSOType => new Set<String>{
                    PACKAGE_QUALIFIER + 'Date__c',
                    PACKAGE_QUALIFIER + 'Vendor__r.Default_Expense_GL_Account__c'
            },
            recurringBillingSOType => new Set<String>{
                    PACKAGE_QUALIFIER + 'Next_Billing_Date__c'
            },
            recurringAccountPayableSOType => new Set<String>{
                    PACKAGE_QUALIFIER + 'Next_Account_Payable_Date__c'
            }
    };
    private static Map<SObjectType, String> childSObjectApiNamesByParentTypes = new Map<SObjectType, String>{
            journalEntrySOType => PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
            billingSOType => PACKAGE_QUALIFIER + 'Billing_Line__c',
            accountPayableSOType => PACKAGE_QUALIFIER + 'Account_Payable_Line__c',
            recurringBillingSOType => PACKAGE_QUALIFIER + 'Recurring_Billing_Line__c',
            recurringAccountPayableSOType => PACKAGE_QUALIFIER + 'Recurring_Account_Payable_Line__c'
    };

    public Boolean isError {get; set;}
    public String redirectUrl {get; set;}

    private Id masterRecordId;

    public class NavToCreateException extends Exception {}
    public NavToCreateController(ApexPages.StandardSetController setCon) {
        this.isError = false;
        this.masterRecordId = ApexPages.currentPage().getParameters().get('id');
        try {
            init();
        }
        catch (Exception ex) {
            this.isError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
        }
    }

    private void init() {
        if (masterRecordId == NULL) {
            throw new NavToCreateException(Label.INF_ID_MASTER_RECORD_REQUIRED_PARAMETER);
        }

        SObjectType masterRecordSOObjType = masterRecordId.getSObjectType();

        Set<String> fields = new Set<String>{'Id'};
        if (fieldsBySObjectTypes.containsKey(masterRecordSOObjType)) {
            fields.addAll(fieldsBySObjectTypes.get(masterRecordSOObjType));
        }

        String masterRecordAPIName = masterRecordId.getSObjectType().getDescribe().getName();
        String dynamicQuery =
                'SELECT ' + String.join(new List<String>(fields), ',') +
                ' FROM ' + String.escapeSingleQuotes(masterRecordAPIName) + ' ' +
                ' WHERE Id = :masterRecordId LIMIT 1';
        try {
            SObject masterRecord = Database.query(dynamicQuery)[0];

            String defaultFieldValues = null;
            List<String> params = new List<String>();
            if (masterRecordSOObjType == journalEntrySOType) {
                Date journalDate = (Date)masterRecord.get(PACKAGE_QUALIFIER + 'Journal_Date__c');
                params = new List<String>{
                        PACKAGE_QUALIFIER + 'Journal_Entry__c=' + masterRecordId,
                        PACKAGE_QUALIFIER + 'Date__c=' + getFormattedDate(journalDate)
                };
            } else if (masterRecordSOObjType == billingSOType) {
                Date billingDate = (Date)masterRecord.get(PACKAGE_QUALIFIER + 'Date__c');
                params = new List<String>{
                        PACKAGE_QUALIFIER + 'Billing__c=' + masterRecordId,
                        PACKAGE_QUALIFIER + 'Date__c=' + getFormattedDate(billingDate)
                };
            } else if (masterRecordSOObjType == accountPayableSOType) {
                Date issueDate = (Date)masterRecord.get(PACKAGE_QUALIFIER + 'Date__c');
                params = new List<String>{
                        PACKAGE_QUALIFIER + 'Account_Payable__c=' + masterRecordId,
                        PACKAGE_QUALIFIER + 'Date__c=' + getFormattedDate(issueDate)
                };
            } else if (masterRecordSOObjType == recurringBillingSOType) {
                Date nextBillingDate = (Date)masterRecord.get(PACKAGE_QUALIFIER + 'Next_Billing_Date__c');
                params = new List<String>{
                        PACKAGE_QUALIFIER + 'Recurring_Billing__c=' + masterRecordId,
                        PACKAGE_QUALIFIER + 'Date__c=' + getFormattedDate(nextBillingDate)
                };
            } else if (masterRecordSOObjType == recurringAccountPayableSOType) {
                Date nextPayableDate = (Date)masterRecord.get(PACKAGE_QUALIFIER + 'Next_Account_Payable_Date__c');
                params = new List<String>{
                        PACKAGE_QUALIFIER + 'Recurring_Account_Payable__c=' + masterRecordId,
                        PACKAGE_QUALIFIER + 'Date__c=' + getFormattedDate(nextPayableDate)
                };
            }

            if (!params.isEmpty()) {
                defaultFieldValues = String.join(params, ',');
            }

            String backgroundContext = String.format('/lightning/r/{0}/{1}/view', new List<String>{
                    masterRecordAPIName, masterRecordId
            });
            this.redirectUrl = String.format('/lightning/o/{0}/new?backgroundContext={1}&defaultFieldValues={2}&navigationLocation=RELATED_LIST', new List<String>{
                    childSObjectApiNamesByParentTypes.get(masterRecordSOObjType), EncodingUtil.urlEncode(backgroundContext, 'utf-8'), defaultFieldValues
            });
        }
        catch (Exception ex) {
            throw new NavToCreateException(Label.ERR_CANNOT_QUERY_MASTER_RECORD_ERROR + ex.getMessage());
        }
    }

    private String getFormattedDate(Date dateVal) {
        return (
                dateVal != null ?Datetime.newInstance(dateVal, Time.newInstance(0, 0, 0, 0)) : Datetime.now()
        ).format('yyyy-MM-dd');
    }
}