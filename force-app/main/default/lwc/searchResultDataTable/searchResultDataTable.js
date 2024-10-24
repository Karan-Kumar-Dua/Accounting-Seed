import { LightningElement, track, api } from 'lwc';
import { ErrorUtils, NotificationService, LabelService } from "c/utils";
import { tableLabels } from './searchResultDataTableLabels';

export default class SearchResultDataTable extends LightningElement {
    @api searchData;

    @track result;
    @track columns;
    @track error;
    @track isError;

    labelData = {...LabelService, ...tableLabels()};

    connectedCallback() {
        this.handleSearch();
    }

    handleSearch() {
        try {
            let resultData = JSON.parse(JSON.stringify(this.searchData));
            let cols;
            if(resultData.data.length > 0){
                resultData.data.forEach(row => {
                    cols = resultData.columns.map(item => {
                        if (item.isNameField) {
                            row.nameLink = '/' + row.Id;
                            return {
                                label: item.label, fieldName: 'nameLink', type: 'url', typeAttributes: {
                                    label: { fieldName: 'Name' },
                                    target: '_blank'
                                }
                            };
                        }
                        if (item.type === 'reference') {
                            let crossFields = item.typeAttributes.label.fieldName.split('.'); 
                            row.lookupValue = (row.hasOwnProperty(crossFields[0]))?(crossFields.reduce((accumulator, currentValue) => (row[accumulator][currentValue]))):'';            
                            row.lookupLink = (row.hasOwnProperty(crossFields[0]))?('/' + row[item.apiName]):'';
                            return {
                                label: item.label, fieldName: 'lookupLink', type: 'url', typeAttributes: {
                                    label: { fieldName: 'lookupValue' },
                                    target: '_blank'
                                }
                            };
                        }
                        if (item.type === 'currency') {
                            row[item.apiName] = parseFloat(row[item.apiName]).toFixed(2);
                            return {
                                label: item.label, fieldName: item.apiName, type: 'text', cellAttributes: {
                                    alignment: 'right'
                                }
                            };
                        }
                        else {
                            return { label: item.label, fieldName: item.apiName };
                        }
                    });
                });

                this.columns = cols;
                this.result = resultData.data;
                
            }else{
                this.columns = resultData.columns;
                this.result = [];
            }
            
        }
        catch (err) {
            NotificationService.displayToastMessage(this, err.message, this.labelData.ERR_IN_SEARCH_TABLE + ':', LabelService.commonErrorText);
        }
    }

    @api
    getDatatable() {
        return this.refs.stdtable;
    }

    getSelectedRows(evt) {
        const rowSelection = new CustomEvent('rowselect', {
            detail: {
               selectRows: evt.detail.selectedRows
            },
        });

        this.dispatchEvent(rowSelection);
    }

    processError(e) {
        let { isError, error } = ErrorUtils.processError(e);
        if (isError) {
            this.error = error;
            this.isError = isError;
        } else {
            this.error = error.toString();
            this.isError = true;
        }
    }

}