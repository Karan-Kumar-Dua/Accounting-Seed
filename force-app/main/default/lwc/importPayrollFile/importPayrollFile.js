import { LightningElement, track } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { NotificationService, LabelService } from 'c/utils';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import getTransactionalLedger from '@salesforce/apex/PayrollFileImport.getTransactionalLedger';
import getGlavsLabels from '@salesforce/apex/PayrollFileImport.getGlavsLabels';
import saveRecords from '@salesforce/apex/PayrollFileImport.saveRecords';
import Labels from './labels';

const JOURNAL_ENTRY_INFO = LabelService.importPayrollUniqueJournalEntryNameInfo;
const TRANSACTION_DATE_INFO = LabelService.importPayrollTransactionDateInfo;
const GL_ACCOUNT_INFO = LabelService.importPayrollGlAccountInfo;
const POSITIVE_DEBIT_INFO = LabelService.importPayrollPositiveDebitInfo;
const POSITIVE_CREDIT_INFO = LabelService.importPayrollPositiveCreditInfo;
const COMMON_ERROR_MESSAGE_HEADING = LabelService.importPayrollCommonErrorMessageHeading;
const COMMON_ERROR_MESSAGE_REQUIRED_COLUMNS = LabelService.importPayrollCommonErrorMessageRequiredColumns;
const COMMON_ERROR_MESSAGE_DUPLICATES = LabelService.importPayrollCommonErrorMessageDuplicates;
const COMMON_ERROR_MESSAGE_OPTIONAL_COLUMNS = LabelService.importPayrollCommonErrorMessageOptionalColumns;
const COMMON_ERROR_MESSAGE_THOUSAND_ROWS = LabelService.importPayrollCommonErrorMessageThousandRows;

const REQUIREMENT_MESSAGE = '<ul class="slds-list_dotted"><li>'+JOURNAL_ENTRY_INFO+'</li><li>'+TRANSACTION_DATE_INFO+'</li><li>'+GL_ACCOUNT_INFO+'</li><li>'+POSITIVE_DEBIT_INFO+'</li><li>'+POSITIVE_CREDIT_INFO+'</li></ul>';
const COMMON_ERROR_MESSAGE = '<ul class="slds-list--dotted"><b>'+COMMON_ERROR_MESSAGE_HEADING+'</b><li>'+COMMON_ERROR_MESSAGE_REQUIRED_COLUMNS+'</li><li>'+COMMON_ERROR_MESSAGE_DUPLICATES+'</li><li>'+COMMON_ERROR_MESSAGE_OPTIONAL_COLUMNS+'</li><li>'+COMMON_ERROR_MESSAGE_THOUSAND_ROWS+'</li></ul>';
export default class ImportPayrollFile extends LightningElement {
    labels = {...LabelService, ...Labels};
    @track lineWrapper;
    @track isValidFile = false;
    @track isTableLoading = false;
    @track isCreatedRec = false;
    @track isDepartmentExist = false;
    @track showMessage = false;
    @track showTable = false;
    @track message;
    @track messageSeverity;
    @track ledgerId;
    @track fileName;
    @track fileBody;
    @track requirementMessage;
    @track optionsLedgers;
    @track optionsGlavs;
    @track glavsLabels;
    @track departmentGlavName;
    @track departmentColumnValues;
    @track tableColumns;
    @track commonErrorMessage = COMMON_ERROR_MESSAGE;

    connectedCallback() {
        loadScript(this, staticResource + '/javascript/papaparse.min.js')
        this.requirementMessage = REQUIREMENT_MESSAGE;
        this.getLedger();
        this.getGls();
    }

    getLedger() {
        getTransactionalLedger()
            .then(result => {
                let index = 0;
                this.optionsLedgers = [];
                for (const key in result) {
                    this.optionsLedgers = [...this.optionsLedgers, { label: key, value: result[key] }]
                    if (index === 0) {
                        this.ledgerId = result[key];
                    }
                    index++;
                }
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            });
    }

    getGls() {
        getGlavsLabels()
            .then(result => {
                this.glavsLabels = result;
                this.setGlavsLabels(result);
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            });
    }

    handleFileUpload(event) {
        this.showMessage = false;
        let uploadedFile = event.target.files[0];
        this.fileName = uploadedFile.name;
        this.getData(uploadedFile);
    }

    getData(file) {
        let fileReader = new FileReader();
        let fileContents;
        fileReader.onloadend = (() => {
            fileContents = fileReader.result;
            this.fileBody = fileContents;
            this.parseTheFile(fileContents)
                .then(result => {
                    this.parseOnComplete(result);
                })
                .catch(error => {
                    NotificationService.displayToastMessage(
                        this,
                        error.body.message,
                        `${LabelService.commonToastErrorTitle}:`,
                        'error'
                    );
                });
        });
        fileReader.readAsText(file);
    }

    parseTheFile(fileContent) {
        return new Promise(function (complete, error) {
            Papa.parse(fileContent, { complete, error });
        });
    }

    parseOnComplete(fileBody) {
        let dataArray = fileBody.data;
        let headerRow = dataArray.shift().map(function (val) {
            return val.toLowerCase().trim();
        });
        this.removeEmptyLines(dataArray);
        if (dataArray.length === 0) {
            this.isCreatedRec = true;
        }
        let headerErrorObj = this.isValidFileHeaders(headerRow);
        let rowErrorObj = this.isLessThan1000Rows(dataArray);

        let isExistDepartmentColumn = this.checkDepartmentColumn(headerRow);
        if (isExistDepartmentColumn) {
            this.getDepartmentValues(dataArray, headerRow);
        }
        if (headerErrorObj.isMessage) {
            this.showMessageContent(headerErrorObj);
        }
        else if (rowErrorObj.isMessage) {
            this.showMessageContent(rowErrorObj);
        }
        else {
            this.isValidFile = true;
            this.isTableLoading = true;
            let formattedData = this.formatDataArray(dataArray, headerRow);
            this.createColumnsSet(headerRow);
            if (isExistDepartmentColumn) {
                this.populateDepartmentColumn(formattedData);
                this.setGlavsOptions(headerRow);
            }
            this.lineWrapper = formattedData;
            this.showTable = true;
        }
    }

    handleTableLoaded(){
        this.isTableLoading = false;
    }

    removeEmptyLines(dataArray) {
        let index = [];
        dataArray.forEach((value, i) => {
            let isEmpty = true;
            value.forEach((val) => {
                if (val) {
                    isEmpty = false;
                }
            });
            if (isEmpty === true) {
                index.push(i);
            }
        });
        index.reduceRight(function (previousValue, currentValue) {
            dataArray.splice(currentValue, 1);
        }, (index.length - 1));
    }

    isValidFileHeaders(headerRow) {
        let errorMsg;
        let errorObject = this.createMessageObject();
        let isError = false;
        if (headerRow.length < 5 || !this.isValidHeaderNames(headerRow)) {
            isError = true;
            errorMsg = this.commonErrorMessage;
        }
        else if (this.isExistDuplicateField(headerRow)) {
            isError = true;
            errorMsg = this.commonErrorMessage;
        }
        if (isError) {
            errorObject.isMessage = true;
            errorObject.message = errorMsg;
            errorObject.messageSeverity = "error";
        }

        return errorObject;
    }

    isValidHeaderNames(headerRow) {
        if (headerRow[0] !== "journal entry"
            || headerRow[1] !== "date"
            || headerRow[2] !== "gl account"
            || headerRow[3] !== "debit"
            || headerRow[4] !== "credit") {
            return false;
        }
        return true;
    }

    createMessageObject() {
        return { "isMessage": false, "message": null, "messageSeverity": null };
    }

    isExistDuplicateField(headerRow) {
        let glavsLabels = this.glavsLabels;
        let result = [];
        let duplicate = false;
        headerRow.forEach((val) => {
            let key = glavsLabels.hasOwnProperty(val) ? glavsLabels[val].toLowerCase().trim() : null;
            if (val && result.includes(val) || result.includes(key)) {
                duplicate = true;
            }
            result.push(val);
            if (key) {
                result.push(key);
            }
        });
        return duplicate;
    }

    isLessThan1000Rows(dataArray) {
        let errorMsg = this.commonErrorMessage;
        let errorObject = this.createMessageObject();
        if (dataArray.length > 1000) {
            errorObject.isMessage = true;
            errorObject.message = errorMsg;
            errorObject.messageSeverity = "error";
        }
        return errorObject;
    }

    checkDepartmentColumn(headerRow) {
        let glavsLabels = this.glavsLabels;
        if (headerRow.includes('department') && !Object.values(glavsLabels).map((v) => { return v.toLowerCase().trim() }).includes('department')) {
            this.isDepartmentExist = true;
            return true;
        }
        else {
            this.isDepartmentExist = false;
            return false;
        }
    }

    getDepartmentValues(dataArray, headerRow) {
        let result = [];
        let index;
        // Find department column index
        headerRow.forEach((val, i) => {
            if (val.toLowerCase().trim() == 'department') {
                index = i;
            }
        });
        // select all department column values
        dataArray.forEach((value) => {
            result.push(value[index].trim());
        });
        this.departmentColumnValues = result;
    }

    showMessageContent(msgObj) {
        this.showMessage = msgObj.isMessage;
        this.messageSeverity = msgObj.messageSeverity;
        this.message = msgObj.message;
    }

    formatDataArray(dataArray, headerRow) {
        let fieldOrderMap = this.formatHeaderFieldOrder(headerRow);
        let result = [];
        let lineCount = 1;
        // format correct order data array
        dataArray.forEach((value) => {
            let res = Array(headerRow.length + 5).fill('');
            value.forEach((val, i) => {
                let key = Object.keys(fieldOrderMap)[i];
                res[fieldOrderMap[key] + 2] = val.trim();
                res[0] = lineCount;
            });
            result.push(this.createWrapperObject(res));
            lineCount++;
        });

        return result;
    }

    formatHeaderFieldOrder(headerRow) {
        let glavsLabels = this.glavsLabels;
        let sortOrder = this.getSortOrder();
        let k = Object.keys(sortOrder).length;
        let sortOrderKeys = Object.keys(sortOrder);
        return headerRow.reduce(function (a, b, c) {
            let contains;
            for (let i = 0; i < Object.keys(sortOrder).length; i++) { // select allowed fields
                let key = glavsLabels.hasOwnProperty(sortOrderKeys[i]) ? glavsLabels[sortOrderKeys[i]].toLowerCase().trim() : sortOrderKeys[i];
                if (key === b) {
                    a[b] = i;
                    contains = true;
                }
                else if (sortOrderKeys[i] === b) {
                    a[b] = i;
                    contains = true;
                }
            }
            if (!contains) { // select other any fields
                a[b] = k;
                k++;
            }
            return a;
        }, {});
    }

    getSortOrder() {
        let result = {
            "journal entry": "masterRecordName",
            "date": "stringTransDate",
            "gl account": "glAccountName",
            "debit": "debitAmount",
            "credit": "creditAmount",
            "reference": "externalId",
            "department": "department",
            "gl variable 1": "glVariable1Name",
            "gl variable 2": "glVariable2Name",
            "gl variable 3": "glVariable3Name",
            "gl variable 4": "glVariable4Name",
            "account": "accountName",
            "project": "projectName",
            "project task": "projectTaskName"
        };
        if (!this.isDepartmentExist) {
            delete result.department;
        }
        return result;
    }

    createWrapperObject(dataArray) {
        let result = {
            lineNumber: null,
            status: null,
            masterRecordName: null,
            stringTransDate: null,
            glAccountName: null,
            debitAmount: "",
            creditAmount: "",
            externalId: null,
            department: null,
            glVariable1Name: "",
            glVariable2Name: "",
            glVariable3Name: "",
            glVariable4Name: "",
            accountName: "",
            projectName: "",
            projectTaskName: ""
        };
        if (!this.isDepartmentExist) {
            delete result.department;
        }
        dataArray.forEach((val, i) => {
            if (i <= 15) {
                let keys = Object.keys(result);
                result[keys[i]] = val;
            }
        });

        result.transType = null;
        result.amount = null;
        result.ledgerId = null;
        return result;
    }

    createColumnsSet(headerRow) {
        let result = [{ "title": "Num", "data": "lineNumber" }, { "title": "Status", "data": "status" }];
        let sortOrder = this.getSortOrder();
        let glavsLabels = this.glavsLabels;
        Object.keys(sortOrder).map(function (objectKey) {
            let key = glavsLabels.hasOwnProperty(objectKey) ? glavsLabels[objectKey].toLowerCase().trim() : objectKey;
            if (headerRow.includes(key)) {
                let value = sortOrder[objectKey];
                result.push({ "title": key, "data": value });
            }
            else if (headerRow.includes(objectKey)) {
                let value = sortOrder[objectKey];
                result.push({ "title": objectKey, "data": value });
            }
        });
        this.tableColumns = result;
    }

    populateDepartmentColumn(dataArray) {
        let departmentColumnValues = this.departmentColumnValues;
        dataArray.forEach((value, i) => { // value => one row of Table in rows array
            value.department = departmentColumnValues[i] !== undefined ? departmentColumnValues[i] : "";
        });
    }

    setGlavsOptions(headerRow) {
        let glavsLabels = JSON.parse(JSON.stringify(this.glavsLabels));
        Object.keys(glavsLabels).map(function (objectKey, i) {
            let value = glavsLabels[objectKey];
            if (headerRow.includes(value.toLowerCase().trim()) || headerRow.includes(objectKey)) {
                delete glavsLabels[objectKey];
            }
        });
        this.setGlavsLabels(glavsLabels);
    }

    setGlavsLabels(result) {
        let index = 0;
        this.optionsGlavs = [];
        for (const key in result) {
            this.optionsGlavs = [...this.optionsGlavs, { label: result[key], value: key }];
            if (index === 0) {
                this.departmentGlavName = key;
            }
            index++;
        }
        if (index === 0) {
            this.departmentGlavName = null;
        }
    }

    back(){
        this.showMessage = false;
        this.showTable = false;
        this.isValidFile = false;
        this.isCreatedRec = false;
    }

    createRecord(){
        let dataArray = JSON.parse(JSON.stringify(this.lineWrapper));
        let fileBody = this.fileBody;
        let fileName = this.fileName;
        this.isTableLoading = true;
        if(this.isDepartmentExist){
            this.validateDepartmentAndSetStatus(dataArray);
        }
        this.hideMessage();
        this.populateLedger(dataArray);
        this.removeDepartmentColumn(dataArray);
        saveRecords({dataTable : JSON.stringify(dataArray), fileBody: fileBody, fileName: fileName})
        .then(result=>{
            if (this.isDepartmentExist) {
                this.populateDepartmentColumn(result);
            }

            let isCreated = this.checkCreatedResult(result);
            this.isCreatedRec =  isCreated;

            if (isCreated) {
                let successMessage = this.createMessageObject();
                successMessage.isMessage = true;
                successMessage.message = Labels.INF_RECORDS_SUCCESSFULLY_CREATED;
                successMessage.messageSeverity = "success";
                successMessage.messageTitle = LabelService.commonSuccess;
                this.showToast(successMessage);
            }
            this.lineWrapper = result;
            this.showTable = true;
            this.template.querySelector("c-pay-roll-data-table").updateTableData(this.lineWrapper);            
            this.template.querySelector("c-pay-roll-data-table").parseTheData();            
        })
        .catch(error=>{});
    }

    validateDepartmentAndSetStatus(dataArray){
        let departmentGlavName = this.departmentGlavName;
        let departmentColumnValues = this.departmentColumnValues;
        let sortOrder = this.getSortOrder();
        if (departmentGlavName) {
            dataArray.forEach((value, i) => {
                if (!value[sortOrder[departmentGlavName]]) {
                    value[sortOrder[departmentGlavName]] = departmentColumnValues[i];
                }
            });
        }
    }

    hideMessage(){
        this.showMessage = false;
    }

    populateLedger(dataArray){
        dataArray[0].ledgerId = this.ledgerId;
    }

    removeDepartmentColumn(dataArray){
        dataArray.forEach((value) => {
            delete value.department;
        });
    }
    
    checkCreatedResult(dataArray){
        let result = true;
        dataArray.forEach((value) => {
            if (value.created != true) {
                result = false;
            }
        });
        return result;
    }

    showToast(msgObj){
        NotificationService.displayToastMessage(
            this,
            msgObj.message,
            msgObj.messageTitle,
            msgObj.messageSeverity,
            "dismissable"
        );
    }

    handleLedgerChange(event){
        this.ledgerId = event.detail.value;
    }

    handleDepartmentChange(event){
        this.resetSelectedGlVariable();
        this.departmentGlavName = event.detail.value;
    }

    resetSelectedGlVariable(){
        for(const glVarRow of this.lineWrapper){
            for(const glCol in glVarRow){
                if(glCol.includes("glVariable")){
                    glVarRow[glCol] = "";
                }
            }
        }
    }
}