import {LightningElement, api, track} from 'lwc';
import getNewTimeCardLine from '@salesforce/apex/TimeCardHelper.getNewTimeCardLine';
import saveTimeCardLines from '@salesforce/apex/TimeCardHelper.saveTimeCardLines';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class TimeCardLineEdit extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api timeCardData;
    @api isEditMode = false;
    @api line;

    @track dataLoaded = false;
    @track saveInProgress = false;

    error;
    objectApiName = {"objectApiName":"AcctSeed__Time_Card_Line__c"};

    get timeCardLineId() {
        if (this.line && this.line.timeCardLine) {
            return this.line.timeCardLine.Id;
        }
            return null;
        }

    get timeCardLineName() {
        if (this.line && this.line.timeCardLine) {
            return this.line.timeCardLine.Name;
        }
            return null;
        }

    handleCancel() {
        this.fireCloseLightboxEvent();
    }

    handleSave(event) {
        event.preventDefault();
        let projectWithTaskSelectionCmp = this.template.querySelector('c-project-with-task-selection');
        if (projectWithTaskSelectionCmp.validate()) {
            this.saveInProgress = true;
            let lineCopy = JSON.parse(JSON.stringify(this.line));
            //populate time card line fields populated in form
            for (let field in event.detail.fields) {
                if (Object.prototype.hasOwnProperty.call(event.detail.fields, field)) {
                    lineCopy.timeCardLine[field] = event.detail.fields[field];
                }
            }
            //add Project & Project Task values populated inside nested component
            lineCopy.timeCardLine.AcctSeed__Project__c = projectWithTaskSelectionCmp.getData().projectId;
            lineCopy.timeCardLine.AcctSeed__Project_Task__c = projectWithTaskSelectionCmp.getData().projectTaskId;
            //get rid of days related list (causes JSON.deserialize error on server side)
            lineCopy.timeCardLine.AcctSeed__Time_Card_Days__r = {};

            this.line = lineCopy;
            this.saveLine();
        }
    }

    fireCloseLightboxEvent() {
        this.dispatchEvent(new CustomEvent('tclneweditformdialogclose'));
    }

    fireTclRefreshTableEvent() {
        let eventData = {};
        eventData.operation = (this.isEditMode) ? 'line_update' : 'line_create';
        eventData.data = (this.isEditMode) ? this.timeCardLineName : '';
        this.dispatchEvent(new CustomEvent('tcltablerefresh', {bubbles: true, composed: true, detail: eventData}));
    }

    saveLine() {
        //serialize lines
        let lines = [];
        lines.push(JSON.stringify(this.line));

        saveTimeCardLines({timeCard: this.timeCardData.timeCard, serializedTimeCardLineWrappers: lines})
            .then(() => {
                this.error = undefined;
                this.fireCloseLightboxEvent();
                this.fireTclRefreshTableEvent();
            })
            .catch(error => {
                this.error = error;
                this.saveInProgress = false;
            });
    }

    loadNewLineStub() {
        getNewTimeCardLine({timeCardId: this.timeCardData.timeCard.Id})
            .then(result => {
                this.line = result;
                this.error = undefined;
                this.dataLoaded = true;
            })
            .catch(error => {
                this.error = error;
                this.line = undefined;
                this.dataLoaded = true;
            });
    }

    connectedCallback() {
        if (this.isEditMode) {
            this.dataLoaded = true;
        }
        else {
            this.loadNewLineStub();
        }
    }

}