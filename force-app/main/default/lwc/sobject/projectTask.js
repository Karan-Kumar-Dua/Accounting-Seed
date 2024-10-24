import PROJECT_TASK from "@salesforce/schema/Project_Task__c";
import PROJECT from "@salesforce/schema/Project_Task__c.Project__c";
import NAME_FIELD from '@salesforce/schema/Project_Task__c.Name';

export default class ProjectTask {
    static projectTask = PROJECT_TASK;
    static objectApiName = PROJECT_TASK.objectApiName;

    static project = PROJECT;
    static name_field = NAME_FIELD;

    name_field = NAME_FIELD.fieldApiName;
}