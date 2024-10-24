import {AmortizationEntry, FixedAsset, ProjectTask} from 'c/sobject';
import WizardItem from 'c/wizardItem';
import {getObjectInfo} from 'lightning/uiObjectInfoApi';
import {api, wire} from "lwc";
import {keywords} from 'c/lookupKeywords';
import { LabelService, CommonUtils } from 'c/utils';
import Labels from './labels';

export default class AmortizationWizardAccountingInfo extends WizardItem {
    @api ltngOut;
    @api sObjectName;

    projectTaskLabel;
    projectTaskHelp;
    labels = {...LabelService, ...Labels};

    @wire(getObjectInfo, { objectApiName: '$amortizationEntry.objectApiName'})
    fetchSObjectInfo({data}) {
        data && (
            this.projectTaskLabel = this.getFieldFromObjectInfo(AmortizationEntry.project_task.fieldApiName, data).label,
            this.projectTaskHelp = this.getFieldFromObjectInfo(AmortizationEntry.project_task.fieldApiName, data).inlineHelpText
        )
    }

    get projectTaskContainerClasses() {
        return CommonUtils.computeClasses([
            'slds-form-element',
            this.ltngOut && 'slds-form-element_horizontal' || 'slds-form-element_stacked'
        ]);
    }

    get debit_gl_account() {
        return FixedAsset.objectApiName !== this.sObjectName
            ? this.values[this.amortizationEntry.debit_gl_account.fieldApiName]
            : null;
    }

    get credit_gl_account() {
        return FixedAsset.objectApiName !== this.sObjectName
            ? this.values[this.amortizationEntry.credit_gl_account.fieldApiName]
            : null;
    }

    get product() {
        return this.values[this.amortizationEntry.product.fieldApiName];
    }

    get project() {
        return this.values[this.amortizationEntry.project.fieldApiName];
    }

    get project_task() {
        return this.values[this.amortizationEntry.project_task.fieldApiName];
    }

    get gl_variable1() {
        return this.values[this.amortizationEntry.gl_variable1.fieldApiName];
    }

    get gl_variable2() {
        return this.values[this.amortizationEntry.gl_variable2.fieldApiName];
    }

    get gl_variable3() {
        return this.values[this.amortizationEntry.gl_variable3.fieldApiName];
    }

    get gl_variable4() {
        return this.values[this.amortizationEntry.gl_variable4.fieldApiName];
    }

    getFieldFromObjectInfo = (fieldApiName, objectInfo) => {
        if (objectInfo && objectInfo.fields.hasOwnProperty(fieldApiName)) {
            return objectInfo.fields[fieldApiName];
        }
    }

    handleProjectChange(event) {
        let projectTaskLookup = this.template.querySelector(`c-lookup[data-field-name="${this.amortizationEntry.project_task.fieldApiName}"]`)
        projectTaskLookup.searchFilter = {
            type: keywords.type.ID,
            field: ProjectTask.project.fieldApiName,
            op: keywords.op.EQUAL,
            val: event.target.value
        };
    }

    validateAndRetrieve({isSkipValidation} = {isSkipValidation : false}) {
        const inputs = this.template.querySelectorAll('lightning-input-field,c-lookup');

        let isValid = true;
        let data = {};
        inputs && inputs.forEach(input => {
            !isSkipValidation && !input.reportValidity() && isValid && (isValid = false);
            data[input.fieldName || input.dataset.fieldName] = input.value || (input.selection && input.selection[0] && input.selection[0].id);
        });

        return {isValid, data};
    }

    amortizationEntry = AmortizationEntry;
    projectTask = ProjectTask;
}