import {api} from 'lwc';
import LightningDatatable from 'lightning/datatable';
import LOCALE from '@salesforce/i18n/locale';
import timeCardDayHoursCellTemplate from './timeCardDayCustomDataType.html';
import recordNameCellTemplate from './recordNameCustomDataType.html';
import formattedNumberCellTemplate from './formattedNumberCustomDataType.html';

export default class TimeCardLineCustomDatatable extends LightningDatatable {

    static customTypes = {
        timeCardDayHoursCell: {
            template: timeCardDayHoursCellTemplate,
            // Provide template data here if needed
            typeAttributes: ['internalComment', 'invoiceComment', 'rowId', 'columnId', 'editMode'],
            editable: true
        },
        recordNameCell: {
            template: recordNameCellTemplate,
            typeAttributes: [],
            editable: false
        },
        totalCell: {
            template: formattedNumberCellTemplate,
            typeAttributes: [],
            editable: false
        }
        //more custom types here
    };

    @api
    dayTotals = [];
    @api
    tableTotal;
    @api
    editMode = false;

    footerCells = [];
    firstTimeRender = true;

    @api
    refreshFooter() {
        for (let i = 0; i < this.dayTotals.length; i++) {
            if (this.footerCells && this.footerCells[i]) {
                this.footerCells[i].getElementsByTagName('div')[0].innerText =
                    new Intl.NumberFormat(LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(this.dayTotals[i]);
            }
        }

        if (this.footerCells && this.footerCells[this.dayTotals.length]) {
            this.footerCells[this.dayTotals.length].getElementsByTagName('div')[0].innerText =
                new Intl.NumberFormat(LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(this.tableTotal);
        }
    }

    renderedCallback() {
        if (this.firstTimeRender && this.data.length > 0) {
            let numberOfColumns = this.columns.length;
            let dayStartIndex = this.columns.length - ((this.editMode) ? 9 : 8);
            let table = this.template.querySelector('table');
            if (table) {
                let footer = table.createTFoot();
                let row = footer.insertRow(0);
                row.style.backgroundColor = 'floralwhite';
                let cells = [];
                for (let i = 0; i < numberOfColumns; i++) {
                    let cell = row.insertCell(i);
                    cell.style.fontWeight = 'bold';
                    cell.insertAdjacentHTML('beforeend', '<div>&nbsp;</div>');
                    cells.push(cell);
                }
                for (let i = dayStartIndex; i < dayStartIndex + this.dayTotals.length; i++) {
                    cells[i].getElementsByTagName('div')[0].innerText =
                        new Intl.NumberFormat(LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(this.dayTotals[i - dayStartIndex]);
                    if (!this.editMode) {
                        cells[i].style.textAlign = 'right';
                        cells[i].style.paddingRight = '30px';
                    }
                    this.footerCells.push(cells[i]);
                }
                cells[dayStartIndex + this.dayTotals.length].style.textAlign = 'right';
                cells[dayStartIndex + this.dayTotals.length].getElementsByTagName('div')[0].innerText =
                    new Intl.NumberFormat(LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(this.tableTotal);
                this.footerCells.push(cells[dayStartIndex + this.dayTotals.length]);
                this.firstTimeRender = false;
            }
        }
    }

}