import { LightningElement, api, track } from 'lwc';
import { LabelService } from 'c/utils';
import Labels from './labels';
export default class Paginator extends LightningElement {
    labels = {...Labels, ...LabelService};
    @api pageSize = 25;
    @api hasGoToPage = false;


    @api
    set totalRecords(value = 0) {
        this._totalRecords = value;
        this.pages = this.getPages();
    }
    get totalRecords() {
        return this._totalRecords || 0;
    }

    @api 
    goToPage(pageNum) {
        if (pageNum <= this.getLastPage()) {
            this.currentPage = pageNum;
            this.pages = this.getPages();
        }
        this.dispatchChangeEvent();
    }

    @api
    moveToPage(pageNum){ 
        this.currentPage = pageNum;
        this.pages = this.getPages();
        
        this.dispatchChangeEvent();
    }

    @api
    getCurrentPage() {
        return this.currentPage;
    }

    @track pages = [];
    
    _totalRecords = 0;
    currentPage = 1;

    getLastPage = () => Math.max(Math.ceil(this.totalRecords/this.pageSize), 1);
    filterPages = (first, last) => pages => [...new Set(pages.filter(n => n >= first && n <= last))];
    ascOrder = (a, b) => a - b;
    addEllipsis = pages => {
        return pages.reduce((acc, page) => {
            if (acc.length < 1) {
                acc.push(page);
            } else {
                const previous = acc[acc.length - 1];
                if (previous === '...') {
                    acc.push(page);
                } else if ((previous + 1) === page) {
                    acc.push(page);
                } else {
                    acc.push('...');
                    acc.push(page);
                }
            }
            return acc;
        },[]);
    }
    isEllipsis = x => x === '...';
    pageNumsToPages = pageNums => {
        return pageNums.map((x, idx) => {
            let variant = 'neutral';
            variant = this.isEllipsis(x) ? 'base' : variant;
            variant = x === this.currentPage ? 'brand' : variant;
            return { 
                num: x, 
                idx: idx,
                class: this.isEllipsis(x) ? 'slds-p-right_small slds-p-left_small' : '',
                variant: variant
            };
        });
    }
    getPages() {
        const current = this.currentPage,
              last = this.getLastPage(),
              first = 1,
              delta = 1,
              max = 3 + (delta * 2),                    // current + first + last + (delta to each side of current)
              filter = this.filterPages(first,last);    // partially applied function

              let pageNums = [];

        pageNums.push(first);              
        pageNums.push(last);               
        pageNums.push(current); 
        for (let i=delta; i > 0; i--) {
            pageNums.push(current - i);           
            pageNums.push(current + i);
        }

        pageNums = filter(pageNums);

        // if less than max add more
        if (pageNums.length < max) {
            // if current page is nearer to start
            if ((current - first) < (last - current)) {
                let i = 1;
                while (pageNums.length <= max) {
                    pageNums.push(current + i++);
                }
            // if current page is nearer to end
            } else if ((current - first) > (last - current)) {
                let i = 1;
                while (pageNums.length <= max) {
                    pageNums.push(current - i++);
                }
            }
        }

        pageNums = filter(pageNums).sort(this.ascOrder);
        pageNums = this.addEllipsis(pageNums);

        return this.pageNumsToPages(pageNums);
    }

    connectedCallback() {
        this.pages = this.getPages();
    }

    previousHandler() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.pages = this.getPages();
            this.dispatchChangeEvent();
        }
    }

    nextHandler() {
        if (this.currentPage < Math.ceil(this.totalRecords/this.pageSize)) {
            this.currentPage++;
            this.pages = this.getPages();
            this.dispatchChangeEvent();
        }
    }

    selectHandler(event) {
        const newPage = event.target.value;
        if (this.currentPage !== newPage && newPage !== '...') {
            this.currentPage = newPage;
            this.pages = this.getPages();
            this.dispatchChangeEvent();
        }
    }

    dispatchChangeEvent() {
        this.dispatchEvent(new CustomEvent('change', { 
            detail: (this.currentPage - 1) * this.pageSize 
        }));
    }

    get stylePageBtns() {
        return (this._totalRecords <= this.pageSize ? 'slds-hide' : 'slds-show');
    }
    handleChange(evt){
        evt.stopImmediatePropagation();
    }
    handleKeyPress(evt){
        if(evt.keyCode === 13 && this.handleInputValidity(this.refs.pageNumber.value)){
            this.goToPage(parseInt(this.refs.pageNumber.value));
        }
    }
    handleGoClick(evt){
        if(this.handleInputValidity(this.refs.pageNumber.value)){
            this.goToPage(parseInt(this.refs.pageNumber.value));
        }
    }
    handleInputValidity(value){
        let isValid = false;
        let errorMessage = this.labels.ERR_INVALID_PAGE_NUMBER;
        if(!isNaN(Number(value)) && Number(value) <= this.getLastPage() && Number(value) !== 0){
            errorMessage = '';
            isValid = true;
        }
        this.refs.pageNumber.setCustomValidity(errorMessage);
        this.refs.pageNumber.reportValidity();
        return isValid;
    }
}