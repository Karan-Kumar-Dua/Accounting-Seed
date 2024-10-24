public with sharing class ProjectFromOpportunity {
    private static final String CATEGORY_PROJECT_ERROR = Label.ERR_CATEGORY_PROJECT;
    private static final String PROJECT_EXISTS_WARNING = Label.WRN_PROJECT_EXISTS;
    private static final String NONE_SELECTED_ERROR = Label.ERR_NONE_SELECTED;
    private static final String MAPPING_ERROR = Label.ERR_MAPPING;
    private static final String TEMPLATE_ERROR = Label.ERR_TEMPLATE;
    private static final String SELECT_OPTION_NONE = Label.SELECT_OPTION_NONE;
    private static final String SELECT_OPTION_CREATE = Label.SELECT_OPTION_CREATE;
    @TestVisible
    private static final String SELECT_OPTION_CREATE_VALUE = 'new';
    private static final String STATUS_ACTIVE = 'Active';
    private static final String STRING_REPLACER = '{0}';
    private static final String QUERY_COUNTLINEITEMS_BYOPP = 'SELECT COUNT() FROM OpportunityLineItem WHERE opportunityId = \'' + STRING_REPLACER + '\'';

    @TestVisible
    private Id projectId;
    @TestVisible
    private ProjectDeepClone pdc;

    public String selectedTemplateProject {get; set;}
    public Opportunity opp;
    public Project_Task__c emptyProduct {get; set;}
    public List<SelectOption> tasks {get; private set;}
    public Boolean isShowProductsTable {get; private set;}
    public Boolean isWillClone {get; private set;}
    public Boolean isNoOppProducts {get; private set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public String currencyIsoCode {get; set;}
    public List<SelectOption> projOptions {get; private set;}
    public Boolean isError {get; private set;}

    public OppProductsWrapper productsWrapper {get; set;}

    public ProjectFromOpportunity(ApexPages.StandardController controller) {
        try {
            opp = (Opportunity) controller.getRecord();
            emptyProduct = new Project_Task__c();
            isShowProductsTable = false;
            isNoOppProducts = false;
            isWillClone = false;
            setTemplateCategoryProjects();
            productsWrapper = new OppProductsWrapper(opp);
            //==============================================================================================
            // Query must be executed in the System Context to count the number of projects
            // regardless of current user permissions. This is used to implement application business rule.
            //==============================================================================================
            Integer projectCount = DomainUtils.getProjectCountByOpportunityId(new Set<Id>{opp.Id});

            if (projectCount > 0) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, PROJECT_EXISTS_WARNING));
            }

            Integer productsCount = Database.countQuery(QUERY_COUNTLINEITEMS_BYOPP.replace(STRING_REPLACER, opp.Id));

            if (productsCount <= 0) {
                isNoOppProducts = true;
            }

            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) opp.get('CurrencyIsoCode');
            }
        
            isError = false;
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isError = true;
        }
    }

    public void setTemplateCategoryProjects() {
        projOptions = new List<SelectOption>();

        //Query Projects with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name'
        };

        String queryCondition = 'Template_Project__c = true AND Status__c = :STATUS_ACTIVE ORDER BY Name';
        SOQLBuilder theQuery = new SOQLBuilder(Project__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        projOptions.add(new SelectOption('', SELECT_OPTION_NONE));

        for (Project__c proj : (List<Project__c>) Database.query(theQuery.toSOQL())) {
            projOptions.add(new SelectOption(proj.id, proj.Name));
        }
    }

    public Boolean selectProjectTasks(Id projectId) {
        Boolean result = false;
        tasks = new List<SelectOption>();
        tasks.add(new SelectOption('', SELECT_OPTION_NONE));
        tasks.add(new SelectOption(SELECT_OPTION_CREATE_VALUE, SELECT_OPTION_CREATE));
        //Query Project Tasks with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name'
        };
        String queryCondition = 'Project__c = :projectId';
        SOQLBuilder theQuery = new SOQLBuilder(Project_Task__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        if (Schema.sObjectType.Project_Task__c.isQueryable()) {
            for (Project_Task__c task : (List<Project_Task__c>) Database.query(theQuery.toSOQL())) {
                tasks.add(new SelectOption(task.Id, task.Name));
            }
            productsWrapper.clearTasks();
            isShowProductsTable = true;
            result = true;
        }
        return result;
    }

    public PageReference createOrAddProject() {
        PageReference result;
        try {
            projectId = NULL;
            if (selectedTemplateProject != NULL && selectedTemplateProject != '') {
                projectId = selectedTemplateProject;
                isWillClone = true;
            }
            else
                if (emptyProduct.Project__c != NULL) {
                    projectId = emptyProduct.Project__c;
                    isWillClone = false;
                }
            if (isNoOppProducts) {
                result = saveMapping();
            }
            else {
                if (projectId != NULL) {
                    selectProjectTasks(projectId);
                }
                else {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NONE_SELECTED_ERROR));
                    backToProjectSelect();
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
        return result;
    }

    public void backToProjectSelect() {
        tasks = NULL;
        isShowProductsTable = false;
    }

    public PageReference saveMapping() {
        PageReference result;
        try {
            if (projectId != NULL) {
                Id resultId = productsWrapper.saveMapping(projectId, opp, isWillClone, SELECT_OPTION_CREATE_VALUE);
                if (resultId != NULL) {
                    projectId = resultId;
                    result =  new PageReference('/' + resultId);
                }
            }
            else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, MAPPING_ERROR));
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }

        return result;
    }

    public with sharing class OppProductWrapper {
        public OpportunityLineItem product {get; set;}
        public String task {get; set;}

        public OppProductWrapper() {
            this.product = new OpportunityLineItem();
        }

        public OppProductWrapper(OpportunityLineItem item) {
            this.product = item;
        }

        public Integer setMapping(Id projectId) {
            Integer result = -1;
            if (task != NULL && ((String) task).length() > 0) {
                product.Project__c = projectId;
                if (task.toLowerCase() == SELECT_OPTION_CREATE_VALUE.toLowerCase()) {
                    result = 0;
                }
                else {
                    product.Project_Task__c = (Id) task;
                    result = 1;
                }
            }
            return result;
        }

        public void clearTask() {
            task = NULL;
        }
    }

    public class OppProductsWrapper {
        public List<OppProductWrapper> products {get; set;}

        public OppProductsWrapper(Opportunity oppr) {
            products = new List<OppProductWrapper>();
            //Query Opportunity Products with CRUD and FLS checks
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Quantity',
                'UnitPrice',
                'TotalPrice',
                'Project__c',
                'Project_Task__c'
            };
            String opportunityId = oppr.Id;
            String queryCondition = 'OpportunityId = :opportunityId ORDER BY SortOrder ASC';
            SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            for (OpportunityLineItem item : (List<OpportunityLineItem>) Database.query(theQuery.toSOQL())) {
                products.add(new OppProductWrapper(item));
            }
        }

        public void clearTasks() {
            for (OppProductWrapper product : this.products) {
                product.clearTask();
            }
        }

        public Id saveMapping(Id projectId, Opportunity opp, Boolean isCloning, String newValue) {
            Id result;
            Savepoint sp = Database.setSavepoint();
            try {
                Map<OpportunityLineItem, Project_Task__c> newTasksByProducts = new Map<OpportunityLineItem, Project_Task__c>();
                List<OpportunityLineItem> items = new List<OpportunityLineItem>();

                if (isCloning) {
                    Map<Id, Id> mapOfCloning = cloneProject(projectId, opp);
                    if (mapOfCloning != NULL && mapOfCloning.containsKey(projectId)) {
                        projectId = mapOfCloning.get(projectId);
                    }
                    else {
                        return NULL;
                    }
                    for (OppProductWrapper product : this.products) {
                        if (product.task != NULL && product.task != '' && product.task.toLowerCase() != newValue.toLowerCase()) {
                            if (mapOfCloning.containsKey(Id.valueOf(product.task))) {
                                product.task = mapOfCloning.get(Id.valueOf(product.task));
                            }

                        }
                    }
                }
                for (OppProductWrapper product : this.products) {
                    Integer mappingStatus = product.setMapping(projectId);
                    if (mappingStatus == 0) {
                        newTasksByProducts.put(
                            product.product,
                            new Project_Task__c(
                                Name = product.product.Name.length() > 80 ? product.product.Name.substring(0,79) : product.product.Name,
                                Project__c = projectId,
                                Status__c = STATUS_ACTIVE
                            )
                        );
                    }
                    else
                        if (mappingStatus == 1) {
                            items.add(product.product);
                        }
                }

                Project__c currentProject = queryProject(projectId, new List<String>{'Id', 'Opportunity__c'});
                currentProject.Opportunity__c = opp.Id;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(currentProject, new List<String>{
                    'Opportunity__c'
                });

                SFDCSecurityUtils.insertCheckCRUDAndFLS(newTasksByProducts.values(), new List<String>{
                    'Project__c',
                    'Status__c'
                });

                for (OpportunityLineItem oli : newTasksByProducts.keySet()) {
                    oli.Project__c = projectId;
                    oli.Project_Task__c = newTasksByProducts.get(oli).Id;
                }
                items.addAll(newTasksByProducts.keySet());

                if (Test.isRunningTest()) {
                    //since we cant grant edit access for Opportunity Product obj using out-of-the-box permission set
                    SFDCSecurityUtils.updateProxy(items);//without checks in unit tests only
                }
                else {
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(items, new List<String>{'Project__c','Project_Task__c'});
                }

                result = projectId;
            }
            catch (Exception ex) {
                ApexPages.addMessages(ex);
                Database.rollback(sp);
                throw ex;
            }

            return result;
        }

        private Project__c queryProject(String projectId, List<String> queryFields) {
            String queryCondition = 'Id = :projectId';
            SOQLBuilder theQuery = new SOQLBuilder(Project__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (Project__c) Database.query(theQuery.toSOQL());
        }

        public Map<Id, Id> cloneProject(Id objForCloningId, Opportunity opp) {
            Map<Id, Id> result;
            try {
                ApexPages.StandardController controller = new ApexPages.StandardController(queryProject(objForCloningId, new List<String>{'Id'}));

                ProjectDeepClone pdc = new ProjectDeepClone(controller);
                result = pdc.deepCloneForIds(true);

                if (ApexPages.getMessages().size() > 1 || result == NULL) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, TEMPLATE_ERROR));
                }
                else {
                    pdc.clonedProject.Name = opp.Name.length() > 80 ? opp.Name.substring(0,79) : opp.Name;
                    pdc.clonedProject.Opportunity__c = opp.Id;
                    pdc.clonedProject.Account__c = opp.AccountId;

                    SFDCSecurityUtils.updateCheckCRUDAndFLS(pdc.clonedProject, new List<String>{
                        'Name',
                        'Opportunity__c',
                        'Account__c'
                    });
                }
            }
            catch (Exception ex) {
                throw ex;
            }
            return result;
        }
    }
}