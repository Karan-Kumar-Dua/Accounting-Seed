import { LightningElement, api, track } from 'lwc';
import { LabelService } from 'c/utils';
import Labels from './labels';
export default class PayRollDataTable extends LightningElement {
    labels = {...LabelService, ...Labels};
    @api tableColumns;
    @track tableValues;

    @track columnsList;
    @track listOfData;

    @track totalRecords;
    @track pageSize=50;
    @track pageOffset = 0;
    @track page;
    @track sortBy;
    @track sortDirection;

    connectedCallback(){
        if(this.tableColumns && this.tableValues){
            this.parseTheData();
        }
    }
    @api 
    get tableData(){return this.tableValues;}
    set tableData(val){
        if(val){
            this.tableValues = val;
        }
    }
    @api updateTableData(val){
        this.tableValues = val;
    }
    @api parseTheData(){
        this.columnsList = [];
        this.listOfData = [];
        
        for(const col of this.tableColumns){
            let rec = {};
            switch (col.title) {
                case 'reference':
                    rec = {label: col.title.toUpperCase(), fieldName: col.data, fixedWidth:300, cellAttributes: { alignment: 'left' }, hideDefaultActions:true, sortable:true };
                    break;
                case 'debit':
                case 'credit':
                    rec = {label: col.title.toUpperCase(), fieldName: col.data,  cellAttributes: { alignment: 'right' }, hideDefaultActions:true, sortable:true };
                    break;
                case 'Status':
                    rec = {label: col.title.toUpperCase(), fieldName: col.data+'Link',  cellAttributes: { alignment: 'left' }, hideDefaultActions:true, sortable:true, type: 'url', typeAttributes: {label: { fieldName: col.data }, target: '_blank'}, wrapText : true};
                    break;
                default:
                    rec = {label: col.title.toUpperCase(), fieldName: col.data,  cellAttributes: { alignment: 'left' }, hideDefaultActions:true, sortable:true };
                    break;
            }
            this.columnsList = [...this.columnsList, rec];
        }
        for(const data of this.tableValues){
            let row = {};
            for(const key in data){
                if(key === 'status'){
                    let rowData = "";
                    if(!this.isCreditDebitEqual(data['masterRecordName'])){
                        this.changeStatusCell(300, "slds-text-color_destructive", true);
                        let errMsg = Labels.ERR_BALANCE_CAPS + "\n";
                        errMsg += Labels.ERR_TOTAL_CREDITS_MUST_EQUAL_TOTAL_DEBITS;
                        rowData = errMsg;
                        row[key+"Link"] = errMsg;
                    }
                    else if((""+data[key]).includes(Labels.COMMON_CREATED)){
                        this.changeStatusCell(160, "slds-text-color_success", false);
                        let stringLink = this.getLink(data[key]);
                        row[key+"Link"] = stringLink;
                        rowData = this.labels.importPayrollFileRecordCreatedMessage;
                    }
                    else if((""+data[key]).includes(Labels.COMMON_ALREADY_EXISTS)){
                        this.changeStatusCell(180, "slds-text-color_default", false);
                        let stringLink = this.getLink(data[key]);
                        row[key+"Link"] = stringLink;
                        rowData = Labels.IMPORT_PAYROLL_FILE_JE_RECORD_ALREADY_EXISTS_MESSAGE;
                    }
                    else if((""+data[key]).includes(Labels.COMMON_NOT_VALID)){
                        this.changeStatusCell(300, "slds-text-color_destructive", true);
                        const originalString = data[key];
                        const errorMessage = this.getErrorMessages(originalString);
                        rowData = errorMessage;
                        row[key+"Link"] = errorMessage;
                    }
                    row[key] = rowData;
                }
                else{
                    row[key] = data[key];
                }                
            }
            this.listOfData = [...this.listOfData, row];
        }
        this.dispatchEvent(new CustomEvent('tableloaded'));
        this.updatePageContent(this.listOfData);
    }

    isCreditDebitEqual(jeName){
        let drAmount = 0;
        let crAmount = 0;
        for(const data of this.tableValues){
            if(data.masterRecordName === jeName){
                drAmount += Number(data.debitAmount);
                crAmount += Number(data.creditAmount);
            }
        }
        return crAmount.toFixed(2) === drAmount.toFixed(2);
    }

    getErrorMessages(originalString){
        const strippedString = originalString.replace(/(<([^>]+)>)/gi, " ");
        const strippedArray = strippedString.split(Labels.COMMON_NOT_VALID);
        let msgText = Labels.COMMON_NOT_VALID;
        let index = 0;
        for(const strippedText of strippedArray){
            if(strippedText.trim().length > 0){
                index++;
                msgText += "\n"+index+". "+strippedText.trim();
            }
        }
        if(index === 1){
            msgText = msgText.replace("1.", "");
        }
        return msgText;
    }

    changeStatusCell(width, className, isError, nameOfField){
        for(const obj of this.columnsList){
            if(obj.label === "STATUS"){
                obj.fixedWidth = width;
                obj.cellAttributes.class = className;
                if(isError === true){
                    delete obj.type;
                    delete obj.typeAttributes;
                }
            }
        }
    }

    getLink(stringLink){
        let startIndex = stringLink.indexOf('href=');
        startIndex = startIndex+6;
        return stringLink.substr(startIndex, 19);
    }

    updatePageContent(listData){
        this.totalRecords = listData.length;
        this.pageSize = this.totalRecords < 50 ? this.totalRecords : 50;
        this.page = listData.slice(this.pageOffset, this.pageOffset + this.pageSize);
    }

    handlePageChange({ detail: offset }) {
        this.pageOffset = offset;
        this.page = this.listOfData.slice(offset, offset + this.pageSize);
    }

    get statusMessage(){
        let lastValue = this.pageOffset + this.pageSize < this.totalRecords ? this.pageOffset + this.pageSize : this.totalRecords;
        return `${Labels.COMMON_SHOWING} ${this.pageOffset+1} ${Labels.COMMON_TO} ${lastValue} ${Labels.COMMON_OF} ${this.totalRecords} ${Labels.COMMON_ENTRIES}`
    }

    doSorting(event){
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }

    sortData(fieldname, direction) {
        let parseData = JSON.parse(JSON.stringify(this.page));
        let keyValue = (a) => {
            return a[fieldname];
        };
        let isReverse = direction === 'asc' ? 1: -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; 
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.page = parseData;
    } 

    handleSearchTermChange(event){
        const valueToSearch = event.detail.value;
        this.searchForText(valueToSearch);
    }

    searchForText(valueToSearch){
        let tempList = [];
        for(const data of this.listOfData){
            let flag = false;
            for(const key in data){
                if((""+data[key]).includes(""+valueToSearch) === true){
                    flag = true;
                    break;
                }
            }
            if(flag === true){
                tempList = [...tempList, data];
            }
        }
        this.updatePageContent(tempList);
    }
}