import {api, wire, track} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {NavigationService, NotificationService, LabelService} from 'c/utils';
import {getRecord} from 'lightning/uiRecordApi';
import getTimeCardData from '@salesforce/apex/TimeCardHelper.getTimeCardData';
import Labels from './labels';

const FIELDS = [
    'AcctSeed__Time_Card__c.Name'
];

export default class TimeCardLineAddEdit extends NavigationService {
    labels = {...LabelService, ...Labels};
    //== public reactive properties ============================================
    @api
    objectApiName;
    @api
    recordId;
    @api
    isFullScreenMode = false;
    //== private reactive properties ===========================================
    @track
    dataLoaded = false;
    //== private properties ====================================================
    timeCardData;
    isPreviewMode;
    numberOfLines;
    error;
    //== getters/setters =======================================================
    get isEditMode() {
        return this.currentPageReference &&
            (this.currentPageReference.state.AcctSeed__isEditMode === "true" || this.currentPageReference.state.AcctSeed__isEditMode === true);
    }

    get nonEmptyLineExists() {
        return this.timeCardData && this.timeCardData.lines.length > 0;
    }

    get displayViewAllLink() {
        return !this.isFullScreenMode && this.nonEmptyLineExists;
    }

    get timeCardName() {
        if (this.timeCardRecord && this.timeCardRecord.data && this.timeCardRecord.data.fields) {
            return this.timeCardRecord.data.fields.Name.value;
        }
        return Labels.INF_BACK_TO_TIME_CARD;
    }

    get isEditModeAvailable() {
        return this.timeCardData && this.timeCardData.isEditModeAvailable;
    }

    get showTable() {
        return this.nonEmptyLineExists || this.isEditMode;
    }

    //== wire adapters =========================================================
    // Injects the page reference that describes the current page
    @wire(CurrentPageReference)
    currentPageReference; // NOTE: This value is read-only
    // Get Time Card with Name field value
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    timeCardRecord;

    setTimeCardData(value) {
        this.numberOfLines = (value) ? value.lines.length : 0;
        if (this.isPreviewMode && value.lines.length > 5) {
            let previewLines = new Array();
            for (let i = 0; i < 6; i++) {
                previewLines.push(value.lines[i]);
            }

            value.lines = previewLines;
        }
        return value;
    }

    handleLoadDataFromServer(event) {
        getTimeCardData({timeCardId: this.recordId})
            .then(result => {
                this.timeCardData = this.setTimeCardData(result);
                this.error = undefined;
                this.dataLoaded = true;
                this.showNotification(event);
            })
            .catch(error => {
                this.error = error;
                this.timeCardData = undefined;
                this.dataLoaded = true;
            });
    }

    showNotification(event) {
        if (event && event.detail) {
            let message;
            if (event.detail.operation === 'mass_update') {
                message = Labels.INF_TIME_CARD_LINES_SUCCESSFULLY_UPDATED;
            }
            else if (event.detail.operation === 'line_update') {
                message = Labels.COMMON_TIME_CARD_LINE + ' ' + event.detail.data + ' ' + LabelService.commonHasBeenSuccessfullyUpdated;
            }
            else if (event.detail.operation === 'line_create') {
                message = Labels.INF_NEW_TIME_CARD_LINE_SUCCESSFULLY_CREATED;
            }
            else if (event.detail.operation === 'line_delete') {
                message = Labels.COMMON_TIME_CARD_LINE + ' ' + event.detail.data + ' ' + LabelService.commonHasBeenSuccessfullyDeleted;
            }

            NotificationService.displayToastMessage(this, message);
        }
    }

    handleViewAllClick(evt) {
        // Stop the event's default behavior.
        // Stop the event from bubbling up in the DOM.
        evt.preventDefault();
        evt.stopPropagation();
        let state = {
            AcctSeed__recordId: this.recordId,
            AcctSeed__objectApiName: this.objectApiName,
            AcctSeed__isEditMode: false
        }
        this.navigateToComponent("AcctSeed__TimeCardNavProxy", state);
    }

    handleAddNewLine(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        let state = {
            AcctSeed__recordId: this.recordId,
            AcctSeed__objectApiName: this.objectApiName,
            AcctSeed__isEditMode: true
        }
        this.navigateToComponent("AcctSeed__TimeCardNavProxy", state);
    }

    handleTclTableRefresh(event) {
        event.stopPropagation();
        this.dataLoaded = false;
        this.handleLoadDataFromServer(event);
    }

    navigateToList() {
        this.navigateToListView(this.objectApiName);
    }

    navigateToTimeCard() {
        this.navigateToViewRecordPageByObject(this.recordId, this.objectApiName);
    }

    connectedCallback() {
        //set recordId if current context is not record page
        if (this.recordId === undefined) {
            this.isPreviewMode = false;
            this.recordId = this.currentPageReference.state.AcctSeed__recordId;
            this.objectApiName = this.currentPageReference.state.AcctSeed__objectApiName;
        }
        else {//set preview mode (up to 6 lines)
            this.isPreviewMode = true;
        }

        this.handleLoadDataFromServer();
    }
}