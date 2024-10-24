import {api} from 'lwc';
import LightningDatatable from 'lightning/datatable';
import recordNameTemplate from './recordNameTemplate.html';
import dateTemplate from './dateTemplate.html';
import combiAmountCommentsTemplate from './combiAmountCommentsTemplate.html';
import textTemplate from './textTemplate.html';
import numberTemplate from './numberTemplate.html';


export default class ExpenseLineCustomDatatable extends LightningDatatable {

    static customTypes = {
        recordName: {
            template: recordNameTemplate,
            typeAttributes: [],
            editable: false
        },
        dateCustom: {
            template: dateTemplate,
            typeAttributes: ['editMode', 'rowId', 'colId'],
            editable: true
        },
        combinedAmount: {
            template: combiAmountCommentsTemplate,
            typeAttributes: ['editMode', 'rowId', 'colId'],
            editable: false
        },
        textCustom: {
            template: textTemplate,
            typeAttributes: ['editMode', 'rowId', 'colId'],
            editable: true
        },
        numberCustom: {
            template: numberTemplate,
            typeAttributes: ['editMode', 'rowId', 'colId', 'mileageRate'],
            editable: true
        }
        //more custom types here
    };

    @api
    editMode = false;

}