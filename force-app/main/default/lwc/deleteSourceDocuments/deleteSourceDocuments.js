import {api, LightningElement, wire} from 'lwc';
import {LabelService, KnowledgeBase, NotificationService, ErrorUtils} from "c/utils";
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord} from "lightning/uiRecordApi";
import {AccountingPeriod} from 'c/sobject';
import startDeleteSourceDocumentsJob from "@salesforce/apex/DeleteSourceDocumentsHelper.startDeleteSourceDocumentsJob";
import validateDeleteSourceDocuments from "@salesforce/apex/DeleteSourceDocumentsHelper.validateDeleteSourceDocuments";
import Labels from './labels';

export default class DeleteSourceDocuments extends LightningElement {
    labels = {...LabelService, ...Labels};
    @api recordId;
    @api ltngOut = false;
    @api callBacks;

    showSpinner = true;
    recordName;
    error;

    @wire(getRecord, {recordId: '$recordId', fields: [AccountingPeriod.id_field, AccountingPeriod.name_field]})
    fetchRecord({data, error}) {
        if (data) {
            this.recordName = data.fields.Name.value;
            this.validatePeriod(data.fields.Id.value);
        }
    }

    get helpURL() {
        return KnowledgeBase.deleteSourceDocuments;
    }

    get showModal() {
        return !this.error;
    }

    validatePeriod(recordId) {
        validateDeleteSourceDocuments({periodId: recordId})
            .then(() => {})
            .catch((err) => {
                let {error} = ErrorUtils.processError(err);
                this.error = error.split('{ERR}');
            })
            .finally(() => {this.showSpinner = false});
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.callBacks && this.callBacks.backToRecord && this.callBacks.backToRecord();
    }

    deleteSourceDocuments() {
        this.showSpinner = true;
        startDeleteSourceDocumentsJob({periodId: this.recordId})
            .then(() => {
                NotificationService.displayToastMessage(
                    this,
                    LabelService.deleteSourceDocSuccess,
                    LabelService.commonSuccess,
                    'success'
                );
                this.closeQuickAction();
            }).catch((err) => {
                this.showSpinner = false;
                let {error} = ErrorUtils.processError(err);
                this.error = error;
            });
    }

}