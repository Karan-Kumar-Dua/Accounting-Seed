export default class WindowUtils {

  that;
  elementSelector;
  offset = 120;
  top = '6rem';
  isPinned = false;


  constructor(that, elementSelector) {
    this.that = that;
    this.elementSelector = elementSelector;
    this.that.wu_pinnedIcon = this.getPinnedIcon();
    this.that.wu_pinnedTitle = this.getPinnedTitle();
  }

  getPinnedIcon = () => (this.isPinned ? 'utility:pinned' : 'utility:pin');

  getPinnedTitle = () => (this.isPinned ? 'unpin from top' : 'pin to top');

  handlePinned() {
    this.isPinned = this.isPinned ? false : true;
    this.that.wu_pinnedIcon = this.getPinnedIcon();
    this.that.wu_pinnedTitle = this.getPinnedTitle();
    if (!this.isPinned) {
      this.setDefaultPosition();
    }
  }

  addPinFunction(offset, top) {
    this.offset = offset !== undefined ? offset : this.offset;
    this.top = top !== undefined ? top : this.top;
    document.addEventListener('scroll', this.scrollHandler);
  }

  removePinFunction() {
    this.offset = 120;
    this.top = '6rem';
    document.removeEventListener('scroll', this.scrollHandler);
  }

  scrollHandler = () => this.updatePosition();

  updatePosition() {
    if (window.pageYOffset > this.offset && this.isPinned) {
      this.setFixedPosition();
    }
    else {
      this.setDefaultPosition();
    }
  }

  setFixedPosition() {
    const element = this.element();
    element.setAttribute('style', `position:fixed; top:${this.top}; left:0px; width:100%; z-index: 7000;`);
  }

  setDefaultPosition() {
    const element = this.element();
    element.setAttribute('style', '');
  }

  element = () => this.that.template.querySelector(this.elementSelector);

  // =================== Static methods =============================

  static getXYCoordinates(element, xVal, yVal, xAdjustment, yAdjustment) {
    let topOffset = element.getBoundingClientRect().top;
    return {
      xValue : xVal + xAdjustment,
      yValue : (yVal - topOffset) + yAdjustment,
    };
  }

  static setElementAbsolutePosition(element, coordinates) {
    let left = `left:${coordinates.xValue}px;`;
    let top = `top:${coordinates.yValue}px;`;
    return element.setAttribute('style', `display:block;position:absolute;z-index:9000;${left}${top}`);
  }

  static getScreenWidth() {
    return window.screen.width;
  }


}