import {LightningElement, api, wire, track} from 'lwc';
import getProjectTasks from '@salesforce/apex/FinancialSuiteUtils.getProjectTasks';
import Labels from './labels';

export default class ProjectWithTaskSelection extends LightningElement {

    labels = Labels;
    @api recordId;
    @api objectApiName;
    @api editMode;
    @api projectId;
    @api projectTaskId;

    @track ptOptions  = null;
    @track dataLoaded = false;
    @track projectNotValid = false;

    error;

    @api
    getData() {
        return {
            projectId: this.projectId,
            projectTaskId: this.projectTaskId,
        }
    }

    @api
    validate() {
        let result = true;
        if (this.projectId === undefined || this.projectId === null) {
            this.projectNotValid = true;
            result = false;
        }
        if (this.projectTaskId === undefined || this.projectTaskId === null) {
            let ptComboBox = this.template.querySelector("lightning-combobox");
            if (ptComboBox) {
                ptComboBox.reportValidity();
            }
            result = false;
        }
        return result;
    }

    get customErrorClass() {
        return (this.projectNotValid) ? 'slds-has-error' : '';
    }

    @wire(getProjectTasks, {projectId: '$projectId'})
    wireProjectTasks({error, data}) {
        if (data) {
            this.populatePtOptions(data);
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }

    populatePtOptions(projectTasks) {
        if (projectTasks && projectTasks.length > 0) {
            let comboboxOptions = [];
            projectTasks.forEach(function (pt) {
                comboboxOptions.push({
                    label: pt.Name,
                    value: pt.Id
                });
            });
            this.ptOptions = comboboxOptions;
        }
    }

    handleProjectSelection(event) {
        this.projectNotValid = false;
        this.projectTaskId = null;
        this.ptOptions = null;
        this.projectId = event.detail.value[0];
    }

    handleProjectTaskSelection(event) {
        this.projectTaskId = event.detail.value;
    }

}