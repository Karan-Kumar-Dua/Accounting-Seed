import { LightningElement, api, track} from 'lwc';
import Labels from './labels';

export default class CustomLookupCell extends LightningElement {
    @api label;
    @api searchObject;
    @api searchDisplayField;
    @api searchGroup;
    @api searchLimit;
    @api searchFilter;
    @api disabled = false;
    @api rowId;
    @api colId;
    @api hideSelectionIcon = false;
    @api placeholder = Labels.INF_SEARCH;
    @api customTable = false;
    @api disabledInputVariant = 'label-hidden';//label is hidden by default
    initValue;

    @api 
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val;
        if (this.changedValue !== val) {    // compare the new value and the value in the underlying lookup component
            this._selectedName = null;
            this._selectedIcon = this._selectedIcon !== undefined && this._selectedIcon != null ? this._selectedIcon : 'utility:search';
            this.doUpdate = true;
            this.setSelection();
        }
    }

    connectedCallback() {
        if (this.value != null) {
            this.initValue = this.value;
        }
    }

    @api
    get selectedName() {
        return this._selectedName;
    }
    set selectedName(val) {
        this._selectedName = val;
        if (this.doUpdate === true) {
            this.setSelection();
        }
    }

    @api 
    get selectedIcon() {
        return this._selectedIcon;
    }
    set selectedIcon(val) {
        this._selectedIcon = val;
        if (this.doUpdate === true) {
            this.setSelection();
        }
    }

    @api
    get errors() {
        return this._errors;
    }
    set errors(vals = []) {
        this._errors = this.transformErrors(vals);
    }
    
    @track _errors = [];
    @track selection = [];

    @api
    getValue() {
        const lookup = this.getLookup();
        return lookup.getSelection();
    }

    @api
    setSearchFilter(val) {
        this.searchFilter = val;
    }

    // set the selected item in the underlying lookup component
    setSelection() {
        if(this.value && this.selectedName && this.selectedIcon) {
            this.selection = [{
                id: this.value,
                title: this.selectedName,
                icon: this.selectedIcon
            }];
            this.doUpdate = false;
        }
        else if(!this.value && !this.selectedName) {
            this.selection = [];
            this.doUpdate = false;
        }
    }

    isForward = false;              // is the lookup element in the background?
    changedValue;                   // the selection made by the underlying lookup component
    doUpdate = false;               // update the selected item in the underlying lookup component. required because vars are not all set @ the same time.

    transformErrors(es) {
        const errorMsgs = es
            .filter(e => e.column === this.colId)
            .map(e => e.msg);
        if (errorMsgs.length > 0) {
            return [{ id: 0, message: errorMsgs[0]}];
        } 
        return [];
    }

    scrollHandler = () => this.updateFixedPosition();

    getElement = selector => this.template.querySelector(selector);
    getLookup = () => this.getElement('c-lookup-a');
    getPositionMarker = () => this.getElement('div');

    getBounds = el => el.getBoundingClientRect();
    getPositionMarkerTop = () => this.getBounds(this.getPositionMarker()).top;

    getPosition = () => (this.customTable ? '' : 'position: fixed; ');
    getFixedStyle = top => this.getPosition() + 'right: auto; z-index: 9010; top: ' + top + 'px;';

    setFixedPosition() {
        let lookup = this.getLookup();
        const top = this.getPositionMarkerTop();
        lookup.setAttribute('style',  this.getFixedStyle(top));
    }

    updateFixedPosition() {
        let lookup = this.getLookup();
        const top = this.getPositionMarkerTop() - ((this.getBounds(lookup).height) / 2);
        lookup.setAttribute('style',  this.getFixedStyle(top));
    }

    setRelativePosition() {
        let lookup = this.getLookup();
        lookup.setAttribute('style',  'position: relative;');
    }

    sendForward() {
        if (this.isInTable() && !this.isForward) {
            this.isForward = true;
            this.setFixedPosition();
            document.addEventListener('scroll', this.scrollHandler, { passive: true });
        }
    }

    sendBackward() {
        if (this.isInTable()) {
            this.setRelativePosition();
            document.removeEventListener('scroll', this.scrollHandler);
            this.isForward = false;
        }
    }

    fireCellChangeEvent(value) {
        this.changedValue = value;
        this.dispatchEvent(new CustomEvent('cellchange', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                colId: this.colId,
                rowId: this.rowId,
                value: value
            }
        }));
    }

    isInTable = () => !!(this.rowId && this.colId);

    handleOpen = () => this.sendForward();
    handleBlur = () => this.sendBackward();
    handleChange({ detail }) {
        this.sendBackward();
        this.fireCellChangeEvent(detail);
    }

}