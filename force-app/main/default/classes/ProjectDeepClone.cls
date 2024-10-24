global with sharing class ProjectDeepClone {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    global Project__c clonedProject {get; private set;}
    private Project__c proj;
    @TestVisible
    private Map<Id, Project_Task__c> projTaskMap;
    private List<Task> taskList;

    public Id theNewProjectId {get; set;}
    public Boolean isError {get; set;}

    global ProjectDeepClone(ApexPages.StandardController controller) {
        proj = (Project__c) controller.getRecord();
        theNewProjectId = proj.Id;
        isError = false;
    }

    global Map<Id, Id> deepCloneForIds(Boolean isTasksIds) {
        isError = false;
        Map<Id, Id> result = new Map<Id, Id>();

        Map<String, Schema.SObjectField> projectFieldMap =
            Schema.SObjectType.Project__c.fields.getMap();

        Map<String, Schema.SObjectField> projectTaskFieldMap =
            Schema.SObjectType.Project_Task__c.fields.getMap();

        Map<String, Schema.SObjectField> taskFieldMap =
            Schema.SObjectType.Task.fields.getMap();

        List<String> projFieldList = new List<String>();
        List<String> projTaskFieldList = new List<String>();
        Set<String> taskFieldSet = new Set<String>();

        for (String key : projectFieldMap.keySet()) {
            Schema.DescribeFieldResult field = projectFieldMap.get(key).getDescribe();
            if (field.isUpdateable() && field.isCreateable() && !field.isUnique()) {
                projFieldList.add(field.getName());
            }
        }

        for (String key : projectTaskFieldMap.keySet()) {
            Schema.DescribeFieldResult field = projectTaskFieldMap.get(key).getDescribe();
            if (field.isUpdateable() && field.isCreateable() && !field.isUnique()) {
                projTaskFieldList.add(field.getName());
            }
        }

        for (String key : taskFieldMap.keySet()) {
            Schema.DescribeFieldResult field = taskFieldMap.get(key).getDescribe();
            if (field.isUpdateable() && field.isCreateable() && !field.isUnique()) {
                taskFieldSet.add(field.getName());
            }
        }

        if (!taskFieldSet.contains('WhatId')) {
            taskFieldSet.add('WhatId');
        }

        Savepoint sp = Database.setSavepoint();

        try {
            //Query for Project with CRUD and FLS checks
            Project__c newProject = queryProject(proj.Id, projFieldList);

            clonedProject = newProject.clone(false);
            clonedProject.Template_Project__c = false;
            clonedProject.Name = clonedProject.Name = clonedProject.Name != NULL ? ((clonedProject.Name.length() > 72 ? clonedProject.Name.substring(0,72) : clonedProject.Name) + '_Cloned') : clonedProject.Name;

            SFDCSecurityUtils.insertCheckCRUDAndFLS(clonedProject, new List<String>{
                'Template_Project__c'
            });

            result.put(proj.Id, clonedProject.Id);

            projTaskMap = new Map<Id, Project_Task__c>();

            for (Project_Task__c projTask : queryProjectTasks(proj.Id, projTaskFieldList)) {
                Project_Task__c clonedProjTask = projTask.clone(false);
                clonedProjTask.Project__c = clonedProject.Id;
                projTaskMap.put(projTask.Id, clonedProjTask);
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(projTaskMap.values(), new List<String>());

            if (isTasksIds) {
                for (Id oldTaskId : projTaskMap.keySet()) {
                    result.put(oldTaskId, projTaskMap.get(oldTaskId).Id);
                }
            }

            Set<Id> projTaskSet = projTaskMap.keySet();
            taskList = new List<Task>();

            List<String> taskFieldList = new List<String>();
            taskFieldList.addAll(taskFieldSet);

            for (Task theTask : queryTasks(projTaskSet, taskFieldList)) {
                Task clonedTask = theTask.clone(false);
                clonedTask.ActivityDate = System.today();
                clonedTask.WhatId = projTaskMap.get(theTask.WhatId).Id;// Get the new ProjectTask Ids from the map
                taskList.add(clonedTask);
            }

            // according Financial Suite internal business logic an user must be able to have the ability
            // to insert Task records via this Apex code even if he does not have "Edit Tasks" System Permission
            // enabled in his profile or in assigned Permission Set(s).
            SFDCSecurityUtils.insertProxy(taskList);

            theNewProjectId = clonedProject.Id;
        }
        catch (Exception e) {
            Database.rollback(sp);
            isError = true;
            throw e;
        }

        return result;
    }

    global PageReference deepClone() {
        try {
            deepCloneForIds(false).get(proj.Id);
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            return NULL;
        }
        return new PageReference(FinancialSuiteUtils.getRedirectToSObjectURL(theNewProjectId, Project__c.SObjectType, true));
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

    private List<Project_Task__c> queryProjectTasks(String projectId, List<String> queryFields) {
        String queryCondition = 'Project__c = :projectId';
        SOQLBuilder theQuery = new SOQLBuilder(Project_Task__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Project_Task__c>) Database.query(theQuery.toSOQL());
    }

    private List<Task> queryTasks(Set<Id> projectTaskIds, List<String> queryFields) {
        String queryCondition = 'WhatId IN :projectTaskIds';
        SOQLBuilder theQuery = new SOQLBuilder(Task.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Task>) Database.query(theQuery.toSOQL());
    }

}