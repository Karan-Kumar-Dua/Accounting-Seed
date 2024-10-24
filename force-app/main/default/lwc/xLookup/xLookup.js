import { LightningElement, track, api, wire } from 'lwc';
import apexSearchRecent from '@salesforce/apex/xLookupHelper.searchRecent';
import getSObjectValue from '@salesforce/apex/xLookupHelper.getSObjectValue';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import {CommonUtils,LabelService} from 'c/utils';
import Labels from './labels';

const MINIMAL_SEARCH_TERM_LENGTH = 2; // Min number of chars required to search
const SEARCH_DELAY = 300; // Wait 300 ms after user stops typing then, perform search

export default class XLookup extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api sobjectName;
    @api sobjectFieldName;
    // query params
    @api searchObject;
    @api searchDisplayField;
    @api searchGroup;
    @api searchLimit;
    @api searchFilter;
    // additional display data
    @api label;
    @api selection = [];
    @api placeholder = '';
    @api errors = [];
    @api scrollAfterNItems;
    @api customKey;
    @api hideSelectionIcon;
    @api initValue;
    @api required = false;
    @api fieldLevelHelp;
    @api disabled;
    @api currentRecordIdCursor;

    @api row;

    @api filterItems;

    @track searchTerm = '';
    @track searchResults = [];
    @track hasFocus = false;
    @track showSpinner = false;

    cleanSearchTerm = '';
    blurTimeout;
    searchThrottlingTimeout;
    
    @api 
    get pickSelection(){
        return undefined;
    }
    set pickSelection(val){
        getSObjectValue({objApiName: this.searchObject, objId: val})
                .then(result => {
                    this.setResultValue(result);
                });
    }
    @api
    getSelection() {
        return this.selection;
    }
    @api
    reportValidity() {
        this.required && (
            this.errors = this.selection.length &&
                this.errors.filter(item => item.message !== (this.messages && this.messages.requiredFieldMissingMessage || LabelService.commonCompleteThisField)) ||
                (
                    !this.errors.find(item => item.message === (this.messages && this.messages.requiredFieldMissingMessage || LabelService.commonCompleteThisField)) &&
                        this.errors.push({message: (this.messages && this.messages.requiredFieldMissingMessage || LabelService.commonCompleteThisField)}),
                    this.errors
                )
            
        );
        return !this.errors.length;
    }
    rowData(){
        let filter = '';
        Object.keys(this.row).forEach(item =>{
            if(item !== '_row' && item !== 'rowKey' && item !== '_selected' &&
                item !== '_drawer' && item !== '_updated' && !item.endsWith('__r') && 
                item !== 'attributes' && item !== 'inEditMode' && item !== 'hasError' &&
                item !== 'message' && this.row[item] !== null && this.row[item] !== undefined 
                && this.row[item] !== '' && item !== '_hasSubgrid' && item !== 'childRowKeys'){
                    filter = filter + item + '=' + this.row[item] + ',';
                }
        });
        return filter.endsWith(',') ? filter.substring(0,filter.length-1) : filter;
    }
    get showFieldLevelHelp() {
        return !!this.fieldLevelHelp;
    }

    get isShowRecentRow() {
        return this.searchResults && this.searchResults.length && this.cleanSearchTerm.length < MINIMAL_SEARCH_TERM_LENGTH;
    }

    get recentRecordsLabel() {
        return `Recent ${this.sobjectLabelPlural || LabelService.commomRecords}`;
    }

    setResultValue(result) {
        try {
            if(result === null){this.selection = [];return;}
            this.selection = [{
                id: this.initValue,
                title: result.title,
                icon: this.sobjectIconName || result.icon
            }];
        } catch(e) {}
    }

// EXPOSED FUNCTIONS

    @api
    setSearchResults(results = []) {
        this.searchResults = results.map(result => {
            return {
                id: result.id,
                title: result.title,
                subtitle: result.subtitle,
                icon: this.sobjectIconName || result.icon || 'standard:account',
                currencyIsoCode: result.currencyIsoCode
            };
        });
        this.resetItemsClasses();
        if (this.searchResults.length > 0) {
            this.dispatchEvent(new CustomEvent('open'));
        }
    }
    @wire(getObjectInfo, { objectApiName: '$searchObject' })
    fetchSObjectInfo(result) {
        if (result.data) {
            const sobject = result.data;
            this.sobjectLabelPlural = sobject.labelPlural;

            let iconUrlName = sobject.themeInfo && sobject.themeInfo.iconUrl && sobject.themeInfo.iconUrl.split('/').reverse()[0];
            if (iconUrlName) {
                iconUrlName = iconUrlName.substring(0, iconUrlName.indexOf('_'));
                this.sobjectIconName = `${sobject.custom && 'custom' || 'standard'}:${iconUrlName}`;
            }

            if (this.initValue != null && this.searchObject != null) {
                getSObjectValue({objApiName: this.searchObject, objId: this.initValue})
                    .then(result => this.setResultValue(result));
            }
        }
    }

// INTERNAL FUNCTIONS

    updateSearchTerm(newSearchTerm) {
        this.searchTerm = newSearchTerm;

        // Compare clean new search term with current one and abort if identical
        const newCleanSearchTerm = newSearchTerm.trim().replace(/\*/g, '').toLowerCase();
        if (this.cleanSearchTerm === newCleanSearchTerm && newCleanSearchTerm != '') {
            return;
        }

        this.hasFocus = true;

        // Save clean search term
        this.cleanSearchTerm = newCleanSearchTerm;

        // Apply search throttling (prevents search if user is still typing)
        if (this.searchThrottlingTimeout) {
            clearTimeout(this.searchThrottlingTimeout);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchThrottlingTimeout = setTimeout(() => {
                // Send search event if search term is long enougth
                let requestParams = {};
                requestParams.searchTerm = this.cleanSearchTerm;
                requestParams.sobjectName = this.sobjectName;
                requestParams.sobjectFieldName = this.sobjectFieldName;
                requestParams.rowData = this.cleanSearchTerm.length <= 1 ? this.rowData() + '&searchType=Recent' : this.rowData() + '&searchType=Search';
                this.showSpinner = true;
                (this.cleanSearchTerm.length >= MINIMAL_SEARCH_TERM_LENGTH ?
                    apexSearchRecent(requestParams) : apexSearchRecent(requestParams))
                        .then(response => {
                            if (response) {
                                this.setSearchResults(response);
                            }
                        })
                        .catch(error => {
                            console.error(error);
                        })
                        .finally(() => {this.showSpinner = false});

                this.searchThrottlingTimeout = null;
            },
            SEARCH_DELAY
        );
    }

    isSelectionAllowed() {
        return !this.hasSelection();
    }

    hasResults() {
        return this.searchResults.length > 0;
    }

    hasSelection() {
        return this.selection.length > 0;
    }

    resetItemsClasses() {
        this.searchResults = this.searchResults.map(item => ({
            ...item,
            classes: CommonUtils.computeClasses([item.id === this.currentRecordIdCursor && 'itemOnHover', 'slds-media', 'slds-listbox__option', 'slds-listbox__option_entity', 'slds-listbox__option_has-meta'])
        }));
    }


// EVENT HANDLING

    handleMouseenter(event) {
        this.currentRecordIdCursor = event.currentTarget.dataset.recordid;
        this.resetItemsClasses();
    }

    handleKeydown(event) {
        const recordIdCursorIndex = this.searchResults.findIndex(item => item.id === this.currentRecordIdCursor);
        switch (event.key) {
            case "Down": // IE/Edge specific value
            case "ArrowDown":
                const nextRecordIdCursorIndex = (this.hasFocus && ~recordIdCursorIndex && ((recordIdCursorIndex + 1) % this.searchResults.length)) || 0;
                this.currentRecordIdCursor = this.searchResults[nextRecordIdCursorIndex] && this.searchResults[nextRecordIdCursorIndex].id;
                this.resetItemsClasses();
                this.hasFocus = true;
                break;
            case "Up": // IE/Edge specific value
            case "ArrowUp":
                let prevRecordIdCursorIndex = this.searchResults.length - 1;
                if (this.hasFocus && ~recordIdCursorIndex) {
                    prevRecordIdCursorIndex = !recordIdCursorIndex ? (this.searchResults.length - 1) : (recordIdCursorIndex - 1);
                }
                this.currentRecordIdCursor = this.searchResults[prevRecordIdCursorIndex] && this.searchResults[prevRecordIdCursorIndex].id;
                this.resetItemsClasses();
                this.hasFocus = true;
                break;
            case "Enter":
                const selectedItems = this.searchResults.filter(item => item.id === this.currentRecordIdCursor);
                if (selectedItems.length) {
                    this.selection = [...this.selection, ...selectedItems];
                    this.dispatchEvent(new CustomEvent('selectionchange', {
                        detail: {
                            recordId: this.currentRecordIdCursor,
                            recordName: selectedItems[0].title,
                            currencyIsoCode: selectedItems[0].currencyIsoCode
                        }
                    }));
                }
                this.hasFocus = false;
                break;
            case "Backspace":
                if (!this.hasFocus && this.selection.length) {
                    this.selection = [];
                    // Notify parent components that selection has changed
                    this.dispatchEvent(new CustomEvent('selectionchange'));
                }
                break;
            case "Esc": // IE/Edge specific value
            case "Escape":
                this.hasFocus = false;
                this.currentRecordIdCursor = null;
                break;
        }
    }

    handleInput(event) {
        // Prevent action if selection is not allowed
        if (!this.isSelectionAllowed()) {
            return;
        }
        this.updateSearchTerm(event.target.value);
    }

    handleResultClick(event) {
        const recordId = event.currentTarget.dataset.recordid;
        const recordName = event.currentTarget.dataset.recordname;
        const currencyIsoCode = event.currentTarget.dataset.currencyisocode;
        // Save selection
        let selectedItem = this.searchResults.filter(result => result.id === recordId);
        if (selectedItem.length === 0) {
            return;
        }
        selectedItem = selectedItem[0];
        let newSelection = [...this.selection] || [];
        newSelection.push(selectedItem);
        this.selection = newSelection;

        // Reset search
        if (this.searchTerm) {
            this.searchTerm = '';
            this.searchResults = [];
        }

        // Notify parent components that selection has changed
        this.dispatchEvent(new CustomEvent('selectionchange', { detail: {recordId : recordId, recordName: recordName, currencyIsoCode: currencyIsoCode}}));
    }

    handleComboboxClick() {
        // Hide combobox immediatly
        if (this.blurTimeout) {
            window.clearTimeout(this.blurTimeout);
        }
        this.hasFocus = false;
    }

    handleFocus(event) {
        // Prevent action if selection is not allowed
        this.updateSearchTerm(event.target.value);
        if (!this.isSelectionAllowed()) {
            return;
        }
        this.hasFocus = true;
    }

    handleBlur() {
        // Prevent action if selection is not allowed
        if (!this.isSelectionAllowed()) {
            return;
        }
        // Delay hiding combobox so that we can capture selected result
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.blurTimeout = window.setTimeout(() => {
                this.hasFocus = false;
                this.blurTimeout = null;
            },
            300
        );
    }

    handleClearSelection() {
        this.selection = [];
        this.searchTerm = '';
        this.updateSearchTerm(this.searchTerm);
        // Notify parent components that selection has changed
        this.dispatchEvent(new CustomEvent('selectionchange'));
    }

    @api 
    forceClearSelection(){
        this.handleClearSelection();
    }

// STYLE EXPRESSIONS

    get getContainerClass() {
        let css = 'slds-combobox_container slds-has-inline-listbox ';
        if (this.hasFocus && this.hasResults()) {
            css += 'slds-has-input-focus ';
        }
        if (this.errors.length > 0) {
            css += 'has-custom-error';
        }
        return css;
    }

    get getDropdownClass() {
        let css = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ';
        if (this.hasFocus && this.hasResults()) {
            css += 'slds-is-open';
        } else {
            css += 'slds-combobox-lookup';
        }
        return css;
    }

    get getInputClass() {
        let css = 'slds-input slds-combobox__input has-custom-height ' + (this.errors.length === 0 ? '' : 'has-custom-error ');
        css += 'slds-combobox__input-value ' + (this.hasSelection() ? 'has-custom-border' : '');
        return css;
    }

    get getComboboxClass() {
        let css = 'slds-combobox__form-element slds-input-has-icon ';
        css += (this.hasSelection() && !this.hideSelectionIcon ? 'slds-input-has-icon_left-right' : 'slds-input-has-icon_right');
        return css;
    }

    get getSearchIconClass() {
        return'slds-input__icon slds-input__icon_right ' + (this.hasSelection() ? 'slds-hide' : '');
    }

    get getClearSelectionButtonClass() {
        return 'slds-button slds-button_icon slds-input__icon slds-input__icon_right '
            + (this.hasSelection() ? '' : 'slds-hide');
    }

    get getSelectIconName() {
        return this.hasSelection() ? this.selection[0].icon : 'standard:default';
    }

    get getSelectIconClass() {
        return 'slds-combobox__input-entity-icon '
            + (this.hasSelection() && !this.hideSelectionIcon ? '' : 'slds-hide');
    }

    get getInputValue() {
        return this.hasSelection() ? this.selection[0].title : this.searchTerm;
    }

    get getListboxClass() {
        return 'slds-listbox slds-listbox_vertical slds-dropdown slds-dropdown_fluid '
            + (this.scrollAfterNItems ? 'slds-dropdown_length-with-icon-' + this.scrollAfterNItems : '');
    }

    get isInputReadonly() {
        return this.hasSelection();
    }

    get isExpanded() {
        return this.hasResults();
    }

    get showLabel() {
        return this.label;
    }

}