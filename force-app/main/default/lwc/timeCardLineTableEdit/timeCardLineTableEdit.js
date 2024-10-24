import {api, track} from 'lwc';
import {NavigationService, LabelService} from 'c/utils';
import saveTimeCardLines from '@salesforce/apex/TimeCardHelper.saveTimeCardLines';
import deleteTimeCardLine from '@salesforce/apex/TimeCardHelper.deleteTimeCardLine';
import Labels from './labels';

const actions = [
    {label: LabelService.commonEdit, name: 'edit'},
    {label: LabelService.commonDelete, name: 'delete'}
];

export default class TimeCardLineTableEdit extends NavigationService {
    labels = {...LabelService, ...Labels};
    @api timeCardData;
    @api objectApiName;
    @api recordId;
    @api editMode = false;
    @api fullScreenMode = false;

    @track data = [];
    @track columns;
    @track tableLoadingState = true;
    @track showNewLineDialog = false;
    @track showEditLineDialog = false;
    @track showDeleteLineDialog = false;
    @track showWarning = false;
    @track selectedRow;
    @track dataLoaded = false;
    @track draftValues = [];
    @track errors = {};

    error;
    dataSnapshot;
    isPosted = false;

    get showTable() {
        return this.timeCardData && this.timeCardData.lines && this.timeCardData.lines.length > 0 && !this.isPosted;
    }

    get showAddLineButton() {
        return !this.isPosted && this.editMode;
    }

    initTable() {
        let columns = [
            {label: this.timeCardData.projectFieldOnTclLabel, fieldName: 'project', type: 'recordNameCell'},
            {label: this.timeCardData.projectTaskFieldOnTclLabel, fieldName: 'projectTask', type: 'recordNameCell'}
        ];

        if (this.timeCardData.uiConfig.showBillable) {
            columns.push(
                {label: LabelService.commonBillable, fieldName: 'billable', type: 'boolean'}
            );
        }

        if (this.timeCardData.uiConfig.showOvertime) {
            columns.push(
                {label: LabelService.commonOvertime, fieldName: 'overtime', type: 'boolean'}
            );
        }

        if (this.timeCardData.uiConfig.showTCVariable1) {
            columns.push(
                {label: LabelService.commonVariableOne, fieldName: 'tcVar1', type: 'recordNameCell'}
            );
        }

        if (this.timeCardData.uiConfig.showTCVariable2) {
            columns.push(
                {label: LabelService.commonVariableTwo, fieldName: 'tcVar2', type: 'recordNameCell'}
            );
        }

        this.timeCardData.dayHeaders.forEach(function (element) {
            columns.push({
                label: element, fieldName: element, type: 'timeCardDayHoursCell', typeAttributes: {
                    rowId: {fieldName: 'id'},
                    columnId: element,
                    editMode: this.editMode
                }
            });
        }, this);

        columns.push(
            {label: LabelService.commonTotal, fieldName: 'lineTotal', type: 'totalCell'}
        );

        if (this.editMode) {
            columns.push(
                {type: 'action', typeAttributes: {rowActions: actions, menuAlignment: 'right' }}
            );
        }

        this.columns = columns;
        this.data = this.convertExternalData(this.timeCardData);
        this.dataSnapshot = JSON.parse(JSON.stringify(this.data));
        this.tableLoadingState = false;
        this.dataLoaded = true;
    }

    convertExternalData(extData) {
        let result = [];
        let noHoursValue = (this.editMode) ? null : Number(0).toFixed(2);
        extData.lines.forEach(function(element) {
            let rowData = {
                id: element.timeCardLine.Id,
                name: element.timeCardLine.Name,
                project: element.timeCardLine.AcctSeed__Project__r.Name,
                projectTask: element.timeCardLine.AcctSeed__Project_Task__r.Name
            };

            if (extData.uiConfig.showBillable) {
                rowData.billable = element.timeCardLine.AcctSeed__Billable__c;
            }

            if (extData.uiConfig.showOvertime) {
                rowData.overtime = element.timeCardLine.AcctSeed__Overtime__c;
            }

            if (extData.uiConfig.showTCVariable1) {
                rowData.tcVar1 =
                    (element.timeCardLine.AcctSeed__Time_Card_Variable_1__r)
                        ? element.timeCardLine.AcctSeed__Time_Card_Variable_1__r.Name : '';
            }

            if (extData.uiConfig.showTCVariable2) {
                rowData.tcVar2 =
                    (element.timeCardLine.AcctSeed__Time_Card_Variable_2__r)
                        ? element.timeCardLine.AcctSeed__Time_Card_Variable_2__r.Name : '';
            }

            for (let i = 0; i < element.days.length; i++) {
                let dayContent = {
                    value: (!this.isEmpty(element.days[i].AcctSeed__Hours__c)) ? element.days[i].AcctSeed__Hours__c.toFixed(2) : noHoursValue,
                    internalComment: element.days[i].AcctSeed__Internal_Comment__c,
                    internalCommentAccessible: extData.uiConfig.internalCommentsAccessible,
                    internalCommentUpdateable: extData.uiConfig.internalCommentsUpdateable,
                    invoiceComment: element.days[i].AcctSeed__Invoice_Comment__c,
                    invoiceCommentAccessible: extData.uiConfig.invoiceCommentsAccessible,
                    invoiceCommentUpdateable: extData.uiConfig.invoiceCommentsUpdateable
                };
                rowData[extData.dayHeaders[i]] = dayContent;
            }

            rowData.lineTotal = element.lineTotal;
            result.push(rowData);
        }, this);
        return result;
    }

    isEmpty(value) {
        if (value === undefined || value === null || value === '') {
            return true;
        }
            return false;
        }

    handleAddNewLine() {
        if (this.draftValues && this.draftValues.length > 0) {
            this.showWarning = true;
        }
        else {
            this.showNewLineDialog = true;
        }
    }

    handleRowAction(event) {
        const action = event.detail.action;
        // const row = event.detail.row;
        const rowId = event.detail.row.id;
        switch (action.name) {
            case 'edit':
                this.showRowDetails(rowId);
                break;
            case 'delete':
                this.showDeletePromt(rowId);
                break;
            default:
        }
    }

    showDeletePromt(rowId) {
        this.setSelectedRow(rowId);
        this.showDeleteLineDialog = true;
    }

    showRowDetails(rowId) {
        this.setSelectedRow(rowId);
        this.showEditLineDialog = true;
    }

    setSelectedRow(rowId) {
        for (let i = 0; i < this.timeCardData.lines.length; i++) {
            if (this.timeCardData.lines[i].timeCardLine.Id === rowId) {
                this.selectedRow = this.timeCardData.lines[i];
            }
        }
    }

    handleCellChange(event) {
        event.stopPropagation();
        if (this.checkEventContentIsValid(event)) {
            let columnId = event.detail.columnId;
            let rowId = event.detail.changedCellContent.id;
            let newCellContent = event.detail.changedCellContent[columnId];
            let isExistedUpdated = false;
            let copyDraftValues = JSON.parse(JSON.stringify(this.draftValues));
            copyDraftValues.forEach(function (existedDraftValue) {
                if (existedDraftValue.id === rowId) {
                    existedDraftValue[columnId] = newCellContent;
                    isExistedUpdated = true;
                }
            });

            if (!isExistedUpdated) {
                let newDraftValues = {};
                newDraftValues.id = rowId;
                newDraftValues[columnId] = newCellContent;
                copyDraftValues.push(newDraftValues);
            }

            this.draftValues = copyDraftValues;
            this.recalculateTotals(rowId, columnId, newCellContent.value);
        }
        else {
            this.setTableErrors(event);
        }
    }

    checkEventContentIsValid(event) {
        let result = true;
        if (event.detail.changedCellContent[event.detail.columnId].value
                && (event.detail.changedCellContent[event.detail.columnId].value < 0
                        || event.detail.changedCellContent[event.detail.columnId].value > 24)) {

            result = false;
        }

        if (result && this.errors.rows && this.errors.rows.hasOwnProperty(event.detail.changedCellContent.id)) {
            delete this.errors.rows[event.detail.changedCellContent.id];
        }
        return result;
    }

    setTableErrors(event) {
        let rowError = this.errors.rows;
        if (!rowError) {
            rowError = {};
        }
        rowError[event.detail.changedCellContent.id] = {
            fieldNames: [event.detail.columnId]
        };
        this.errors = {rows:rowError};
    }

    recalculateTotals(rowId, colId, newValue) {
        let tableTotal = 0;
        let dayTotalAggregator = {};

        this.timeCardData.dayHeaders.forEach(function (columnId) {
            dayTotalAggregator[columnId] = 0;
        });

        this.data.forEach(function (eachRowData) {
            if (eachRowData.id === rowId) {
                eachRowData[colId].value = newValue;
                let rowTotal = 0;
                this.timeCardData.dayHeaders.forEach(function (columnId) {
                    rowTotal += parseFloat((eachRowData[columnId].value) ? eachRowData[columnId].value : 0);
                });
                eachRowData.lineTotal = rowTotal;
            }

            this.timeCardData.dayHeaders.forEach(function (columnId) {
                dayTotalAggregator[columnId] += parseFloat((eachRowData[columnId].value) ? eachRowData[columnId].value : 0);
            });

            tableTotal += parseFloat((eachRowData.lineTotal) ? eachRowData.lineTotal : 0);

        }, this);

        let theTable = this.template.querySelector('c-time-card-line-custom-datatable');
        let aggregatedDayTotals = [];
        this.timeCardData.dayHeaders.forEach(function (columnId) {
            aggregatedDayTotals.push(dayTotalAggregator[columnId]);
        });

        theTable.dayTotals = aggregatedDayTotals;
        theTable.tableTotal = tableTotal;
        theTable.refreshFooter();
    }

    handleCancel() {
        this.draftValues = [];
        this.data = JSON.parse(JSON.stringify(this.dataSnapshot));
        let theTable = this.template.querySelector('c-time-card-line-custom-datatable');
        theTable.dayTotals = this.timeCardData.dayHours;
        theTable.tableTotal = this.timeCardData.totalHours;
        theTable.refreshFooter();
    }

    handleCloseDialog() {
        this.showNewLineDialog = false;
        this.showEditLineDialog = false;
        this.showDeleteLineDialog = false;
        this.showWarning = false;
    }

    handleLineDeletion() {
        deleteTimeCardLine({timeCard: this.timeCardData.timeCard, timeCardLineId: this.selectedRow.timeCardLine.Id})
            .then(() => {
                this.error = undefined;
                this.dataLoaded = true;
                this.showDeleteLineDialog = false;

                let eventData = {operation: 'line_delete', data: this.selectedRow.timeCardLine.Name};
                this.dispatchEvent(new CustomEvent('tcltablerefresh', {detail: eventData}));
            })
            .catch(error => {
                this.error = error;
                this.dataLoaded = true;
                this.showDeleteLineDialog = false;
            });
    }

    handleMassUpdate(event) {
        if (this.errors && this.errors.rows && Object.keys(this.errors.rows).length !== 0) {
            return false;
        }
        let saveDraftValues = event.detail.draftValues;
        if (saveDraftValues.length > 0) {
            this.dataLoaded = false;
            let timeCardDataCopy = JSON.parse(JSON.stringify(this.timeCardData));
            timeCardDataCopy.lines.forEach(function(line) {
                let that = this;
                saveDraftValues.forEach(function (saveDraftValue) {
                    if (line.timeCardLine.Id === saveDraftValue.id) {
                        if (saveDraftValue.hasOwnProperty('billable')) {
                            line.timeCardLine.AcctSeed__Billable__c = saveDraftValue.billable;
                        }
                        if (saveDraftValue.hasOwnProperty('overtime')) {
                            line.timeCardLine.AcctSeed__Overtime__c = saveDraftValue.overtime;
                        }
                        let dayIndex = 0;
                        timeCardDataCopy.dayHeaders.forEach(function (dayHeader) {
                            let self = that;
                            if (saveDraftValue.hasOwnProperty(dayHeader)) {
                                //if Hours value was cleared(empty) we must remove related property from object
                                //because this field is required and will be deserialized to 0 in Apex
                                if (self.isEmpty(saveDraftValue[dayHeader].value)) {
                                    delete line.days[dayIndex].AcctSeed__Hours__c;
                                }
                                else {
                                    line.days[dayIndex].AcctSeed__Hours__c = saveDraftValue[dayHeader].value;
                                }
                                line.days[dayIndex].AcctSeed__Internal_Comment__c = saveDraftValue[dayHeader].internalComment;
                                line.days[dayIndex].AcctSeed__Invoice_Comment__c = saveDraftValue[dayHeader].invoiceComment;
                            }
                            dayIndex++;
                        });
                    }
                }, that);

                //get rid of days related list (causes JSON.deserialize error on server side)
                line.timeCardLine.AcctSeed__Time_Card_Days__r = {};
            }, this);

            this.timeCardData = timeCardDataCopy;
            this.saveLines();
        }
        return true;
    }

    saveLines() {
        //serialize lines
        let lines = [];
        this.timeCardData.lines.forEach(function (line) {
            lines.push(JSON.stringify(line));
        });

        saveTimeCardLines({timeCard: this.timeCardData.timeCard, serializedTimeCardLineWrappers: lines})
            .then(() => {
                this.error = undefined;
                this.dataLoaded = true;
                this.dispatchEvent(new CustomEvent('tcltablerefresh', {detail: {operation: 'mass_update'}}));
            })
            .catch(error => {
                this.error = error;
                this.dataLoaded = true;
            });
    }

    navigateToTimeCard() {
        this.navigateToViewRecordPageByObject(this.recordId, this.objectApiName);
    }

    connectedCallback() {
        if (this.editMode && this.timeCardData && this.timeCardData.timeCard.AcctSeed__Status__c === 'Posted') {
            this.isPosted = true;
            this.dataLoaded = true;
        }
        else {
            this.initTable();
        }
    }

}