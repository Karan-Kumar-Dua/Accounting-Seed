public with sharing class TimeCardLineControllerExt {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String LAST_MODIFIED_ERROR = Label.ERR_LAST_MODIFIED;

    private ApexPages.StandardController controller;
    private DateTime lastModifiedDate;
    public Time_Card_Line__c timeCardLine {get; set;}
    public TimeCardHelper.TimeCardLineWrapper timeCardLineWrapper {get; set;}


    //Constructor   
    public TimeCardLineControllerExt(ApexPages.StandardController controller) {
        try {
            this.controller = controller;
            timeCardLine = queryTimeCardLineById(controller.getId());

            timeCardLineWrapper = new TimeCardHelper.TimeCardLineWrapper(
                timeCardLine.Time_Card__r,
                timeCardLine,
                0,
                timeCardLine.Time_Card_Days__r,
                new List<SelectOption>{new SelectOption('', Label.SELECT_OPTION_NONE)}
            );

            lastModifiedDate = timeCardLine.Time_Card__r.LastModifiedDate;
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.Error, Label.ERR_NO_TIME_CARD_LINE_SELECTED));
        }
    }

    // Security Review Note: This class is a controller extension and the fields queried are exposed via Visualforce.
    // Hence, FLS is handled by Visualforce page.
    private Time_Card_Line__c queryTimeCardLineById(String timeCardLineId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Time_Card__c',
            'Project__c',
            'Project_Task__c',
            'Billable__c',
            'Time_Card_Variable_1__c',
            'Time_Card__r.LastModifiedDate',
            'Time_Card__r.Time_Card_Period__r.Start_Date__c',
            'Time_Card__r.Time_Card_Period__r.End_Date__c',
            'Time_Card_Variable_2__c'
        };
        String queryCondition = 'Id = :timeCardLineId';

        List<String> subQueryFields = new List<String>{
            'Id', 'Time_Card_Line__c', 'Date__c', 'Hours__c', 'Internal_Comment__c', 'Invoice_Comment__c'
        };
        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Time_Card_Days__r';
        SOQLBuilder.Ordering subQueryOrdering = new SOQLBuilder.Ordering('Time_Card_Day__c', 'Date__c', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Time_Card_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(subQueryFields)
            .addOrdering(subQueryOrdering);

        return (Time_Card_Line__c) Database.query(theQuery.toSOQL());
    }

    //Save and Navigate
    public PageReference saveBack() {
        List<Time_Card_Day__c> upsertList = new List<Time_Card_Day__c>();
        List<Time_Card_Day__c> deleteList = new List<Time_Card_Day__c>();

        SavePoint sp = Database.setSavepoint();

        try {
            for (Time_Card_Day__c day : timeCardLineWrapper.days) {
                if (day.Time_Card_Line__c == NULL) {
                    day.Time_Card_Line__c = timeCardLineWrapper.timeCardLine.Id;
                }

                if (day.Hours__c != NULL) {
                    upsertList.add(day);
                }
                else if (day.Hours__c == NULL && day.Id != NULL) {
                    deleteList.add(day);
                }
            }

            // Accessible and FLS checks performed in class constructor. Redundant to perform same checks here.
            DateTime checkLastModifiedDate =
                DomainUtils.getTimeCardsByIdForUpdate(new Set<Id>{timeCardLine.Time_Card__c})[0].LastModifiedDate;

            if (checkLastModifiedDate != lastModifiedDate) {
                ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, LAST_MODIFIED_ERROR));
                return NULL;
            }

            //only master-detail field can be potentially be updated that is why we do not need to check any FLS
            SFDCSecurityUtils.upsertCheckCRUDAndFLS(upsertList, new List<String>());

            SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteList);

            // Accessible and FLS checks performed in class constructor. Redundant to perform same checks here.
            lastModifiedDate = DomainUtils.getTimeCardsById(new Set<Id>{timeCardLine.Time_Card__c})[0].LastModifiedDate;
        }
        catch (Exception ex) {
            Database.rollback(sp);
            ApexPages.addMessages(ex);
            return NULL;
        }

        return new PageReference('/apex/TimeCardEdit?Id=' + timeCardLine.Time_Card__c);
    }

}