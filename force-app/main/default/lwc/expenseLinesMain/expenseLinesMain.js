import {api, track, wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {NavigationService, NotificationService, LabelService} from 'c/utils';
import {getRecord} from 'lightning/uiRecordApi';
import getExpenseReportData from '@salesforce/apex/ExpenseReportHelper.getExpenseReportData';
import Labels from './labels';

const FIELDS = [
    'AcctSeed__Expense_Report__c.Name'
];

export default class ExpenseLinesMain extends NavigationService {
    
    labels = {...Labels, ...LabelService};
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
    activeTabValue = 'expenses';
    expenseReportData;
    numberOfLines;
    isPreviewMode;
    error;
    //== getters/setters =======================================================
    @api
    get isEditMode() {
        return this.currentPageReference &&
            (this.currentPageReference.state.AcctSeed__isEditMode === "true" || this.currentPageReference.state.AcctSeed__isEditMode === true);
    }

    get expenseReportName() {
        if (this.expenseReportRecord && this.expenseReportRecord.data && this.expenseReportRecord.data.fields) {
            return this.expenseReportRecord.data.fields.Name.value;
        }
        return Labels.INF_BACK_TO_EXPENSE_REPORT;
    }

    get displayViewAllLink() {
        return !this.isFullScreenMode && this.showTable;
    }

    get expenseLineExists() {
        return this.expenseReportData && this.expenseReportData.expenseLines.length > 0;
    }

    get mileageLineExists() {
        return this.expenseReportData && this.expenseReportData.mileageLines.length > 0;
    }

    get showTable() {
        return this.expenseLineExists || this.mileageLineExists || this.isEditMode;
    }

    get isEditModeAvailable() {
        return this.expenseReportData && this.expenseReportData.isEditModeAvailable;
    }

    //== wire adapters =========================================================
    // Injects the page reference that describes the current page
    @wire(CurrentPageReference)
    currentPageReference; // NOTE: This value is read-only
    // Get Time Card with Name field value
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    expenseReportRecord;

    handleLoadDataFromServer(event) {
        getExpenseReportData({expenseReportId: this.recordId})
            .then(result => {
                this.expenseReportData = this.setExpenseReportData(result);
                this.error = undefined;
                this.dataLoaded = true;
                this.showNotification(event);
            })
            .catch(error => {
                this.error = error;
                this.expenseReportData = undefined;
                this.dataLoaded = true;
            });
    }

    setExpenseReportData(value) {
        this.numberOfLines = (value) ? (value.expenseLines.length + value.mileageLines.length) : 0;
        if (this.isPreviewMode) {
            value.expenseLines = this.leaveFirstSixOnly(value.expenseLines);
            value.mileageLines = this.leaveFirstSixOnly(value.mileageLines);
        }
        return value;
    }

    showNotification(event) {
        if (event && event.detail) {
            let message;
            if (event.detail.operation === 'mass_update') {
                message = Labels.INF_EXPENSE_LINES_SUCCESSFULLY_UPDATED;
            }
            else if (event.detail.operation === 'line_update') {
                message = Labels.INF_EXPENSE_LINE + ' ' + event.detail.data + ' ' + LabelService.commonHasBeenSuccessfullyUpdated;
            }
            else if (event.detail.operation === 'line_create') {
                message = Labels.INF_EXPENSE_LINES_SUCCESSFULLY_CREATTED;
            }
            else if (event.detail.operation === 'line_delete') {
                message = Labels.INF_EXPENSE_LINE + ' ' + event.detail.data + ' ' + LabelService.commonHasBeenSuccessfullyDeleted;
            }

            NotificationService.displayToastMessage(this, message);
        }
    }

    leaveFirstSixOnly(lines) {
        let result = lines;
        if (lines && lines.length > 6) {
            let previewLines = new Array();
            for (let i = 0; i < 6; i++) {
                previewLines.push(lines[i]);
            }

            result = previewLines;
        }
        return result;
    }

    handleOpenView(evt) {
        // Stop the event's default behavior.
        // Stop the event from bubbling up in the DOM.
        evt.preventDefault();
        evt.stopPropagation();
        let state = {
            AcctSeed__recordId: this.recordId,
            AcctSeed__objectApiName: this.objectApiName,
            AcctSeed__isEditMode: false
        }
        this.navigateToComponent("AcctSeed__ExpenseReportNavProxy", state);
    }

    handleOpenEdit(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        let state = {
            AcctSeed__recordId: this.recordId,
            AcctSeed__objectApiName: this.objectApiName,
            AcctSeed__isEditMode: true
        }
        this.navigateToComponent("AcctSeed__ExpenseReportNavProxy", state);
    }

    navigateToErList() {
        this.navigateToListView(this.objectApiName);
    }

    navigateToExpenseReport() {
        this.navigateToViewRecordPageByObject(this.recordId, this.objectApiName);
    }

    handleErlTableRefresh(event) {
        event.stopPropagation();
        this.dataLoaded = false;
        this.activeTabValue = event.detail.selectedTab;
        this.handleLoadDataFromServer(event);
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