#!/usr/bin/env python
#
"""
Resizing experiment
"""

# Pick the demo you want below
demo = 'news-settings'
#demo = 'traingroup'


import pygtk
pygtk.require('2.0')
import gtk

class BaseBox(object):
    def __init__(self):
        # Computed during self.initialize()
        self.min_width = 0
        self.min_height = 0
        self.x_resize = 0
        self.y_resize = 0
        self.x_fill = False
        self.y_fill = False

        # Computed during self.compute_initial_position()
        self.x_pos = 0
        self.y_pos = 0
        self.width = 0
        self.height = 0


    def initialize(self):
        raise NotImplementedError

    def compute_initial_position(self, rx, ry, rw, rh):
        """ Request to place self at (rx, ry) to (rx+rw, ty+th) by filling """
        assert rw >= self.min_width
        assert rh >= self.min_height

        if rw == self.min_width:
            self.x_pos = rx
            self.width = rw
        elif self.x_fill:   # rw > self.min_width => can we adjust?
            self.x_pos = rx
            self.width = rw
            self.min_width = rw # Adjust minimal size of widget
        else:
            self.x_pos = rx + (rw - self.min_width) // 2
            self.width = self.min_width

        if rh == self.min_height:
            self.y_pos = ry
            self.height = rh
        elif self.y_fill:   # rh > self.min_height => can we adjust?
            self.y_pos = ry
            self.height = rh
            self.min_height = rh # Adjust minimal size of widget
        else:
            self.y_pos = ry + (rh - self.min_height) // 2
            self.height = self.min_height

    def _compute_max_width(self, req_width):
        """ Return maximal width fitting in L{req_width} """
        assert req_width >= self.min_width

        if self.x_resize == 0:
            return self.min_width
        elif self.x_resize == 1:
            return req_width
        else:
            dw = req_width - self.min_width
            return req_width - (dw % self.x_resize)

    def _compute_max_height(self, req_height):
        """ Return maximal height fitting in L{req_height} """
        assert req_height >= self.min_height

        if self.y_resize == 0:
            return self.min_height
        elif self.y_resize == 1:
            return req_height
        else:
            dh = req_height - self.min_height
            return req_height - (dh % self.y_resize)


    def resize(self, req_x, req_y, req_width, req_height):
        assert req_x == 0
        assert req_y == 0

        req_width = self._compute_max_width(req_width)
        req_height = self._compute_max_height(req_height)
        self.compute_resize(req_x, req_y, req_width, req_height)

    def compute_resize(self, req_x, req_y, req_width, req_height):

        # Set width
        self.width = self._compute_max_width(req_width)

        # Set x position
        if self.width < req_width:
            self.x_pos = req_x + (req_width - self.width) // 2
        else:
            assert self.width == req_width
            self.x_pos = req_x


        # Set height
        self.height = self._compute_max_height(req_height)

        # Set y position
        if self.height < req_height:
            self.y_pos = req_y + (req_height - self.height) // 2
        else:
            assert self.height == req_height
            self.y_pos = req_y

    def __str__(self):
        return "minimal: %d %d, fill: %s %s, resize: %d %d" % \
                (self.min_width, self.min_height, self.x_fill, self.y_fill,
                 self.x_resize, self.y_resize)

class BaseWidget(BaseBox):
    def __init__(self, xfill, yfill, min_width, min_height, xresize, yresize):
        self.min_width = min_width
        self.min_height = min_height
        self.x_resize = xresize
        self.y_resize = yresize

        self.x_fill = xfill
        self.y_fill = yfill
        assert self.x_fill in [False, True]
        assert self.y_fill in [False, True]

    def initialize(self):
        pass    # Already initialized during construction

    def draw_widget(self, drawable, gc):
        drawable.draw_rectangle(gc, False, self.x_pos, self.y_pos,
                                           self.width-1, self.height-1)


class HBox(BaseBox):
    def __init__(self, box_list):
        self.box_list = box_list
        assert len(self.box_list) > 0

    def initialize(self):
        self.min_width = 0
        self.min_height = 0
        self.x_fill = False
        self.y_fill = True
        self.x_resize = 0
        self.y_resize = 1
        for box in self.box_list:
            box.initialize()
            self.min_width = self.min_width + box.min_width
            if box.min_height > self.min_height:
                self.min_height = box.min_height
            if not self.x_fill and box.x_fill:
                self.x_fill = True
            if self.y_fill and not box.y_fill:
                self.y_fill = False
            if self.x_resize == 0 and box.x_resize > 0:
                self.x_resize = box.x_resize
            if self.y_resize > 0 and \
               (box.y_resize == 0 or box.y_resize > self.y_resize):
                self.y_resize = box.y_resize

    def compute_initial_position(self, rx, ry, rw, rh):
        dw = rw - self.min_width    # Rescue self.min_width difference first
        BaseBox.compute_initial_position(self, rx, ry, rw, rh)

        xp = self.x_pos
        for box in self.box_list:
            if dw > 0 and box.x_fill:
                box.compute_initial_position(xp, self.y_pos,
                                             box.min_width + dw, self.height)
                dw = 0
            else:
                box.compute_initial_position(xp, self.y_pos,
                                             box.min_width, self.height)
        
            xp = xp + box.width


    def draw_widget(self, drawable, gc):
        for box in self.box_list:
            box.draw_widget(drawable, gc)


    def compute_resize(self, req_x, req_y, req_width, req_height):
        BaseBox.compute_resize(self, req_x, req_y, req_width, req_height)

        # Additional space to resolve in resizing
        dw = self.width - self.min_width

        xp = self.x_pos
        for box in self.box_list:
            if dw > 0 and box.x_resize > 0:
                box_width = box.min_width + dw
                assert dw % box.x_resize == 0
                dw = 0
            else:
                box_width = box.min_width

            box.compute_resize(xp, self.y_pos, box_width, self.height)
            xp = xp + box_width


class VBox(BaseBox):
    def __init__(self, box_list):
        self.box_list = box_list
        assert len(self.box_list) > 0

    def initialize(self):
        self.min_height = 0
        self.min_width = 0
        self.y_fill = False
        self.x_fill = True
        self.y_resize = 0
        self.x_resize = 1
        for box in self.box_list:
            box.initialize()
            self.min_height = self.min_height + box.min_height
            if box.min_width > self.min_width:
                self.min_width = box.min_width
            if not self.y_fill and box.y_fill:
                self.y_fill = True
            if self.x_fill and not box.x_fill:
                self.x_fill = False
            if self.x_resize > 0 and \
               (box.x_resize == 0 or box.x_resize > self.x_resize):
                self.x_resize = box.x_resize
            if self.y_resize == 0 and box.y_resize > 0:
                self.y_resize = box.y_resize

    def compute_initial_position(self, rx, ry, rw, rh):
        dh = rh - self.min_height    # Rescue self.min_height difference first
        BaseBox.compute_initial_position(self, rx, ry, rw, rh)

        yp = self.y_pos
        for box in self.box_list:
            if dh > 0 and box.y_fill:
                box.compute_initial_position(self.x_pos, yp,
                                             self.width, box.min_height + dh)
                dh = 0
            else:
                box.compute_initial_position(self.x_pos, yp,
                                             self.width, box.min_height)
        
            yp = yp + box.height


    def draw_widget(self, drawable, gc):
        for box in self.box_list:
            box.draw_widget(drawable, gc)

    def compute_resize(self, req_x, req_y, req_width, req_height):
        BaseBox.compute_resize(self, req_x, req_y, req_width, req_height)

        # Additional space to resolve in resizing
        dh = self.height - self.min_height

        yp = self.y_pos
        for box in self.box_list:
            if dh > 0 and box.y_resize > 0:
                box_height = box.min_height + dh
                assert dh % box.y_resize == 0
                dh = 0
            else:
                box_height = box.min_height

            box.compute_resize(self.x_pos, yp, self.width, box_height)
            yp = yp + box_height



class Area(object):
    def __init__(self):
        self.win= gtk.Window(gtk.WINDOW_TOPLEVEL)

        self.win.connect("delete_event", self.delete_event)
        self.win.connect("destroy", self.destroy)
        self.win.connect("size_allocate", self.size_alloc_event)

        self.area = gtk.DrawingArea()
        self.area.connect("expose_event", self.expose)

        if demo == 'news-settings':
            self.main_widget = self.news_window_init()
        elif demo == 'traingroup':
            self.main_widget = self.traingroup_window_init()
        else:
            raise ValueError("Choose a demo")

        self.main_widget.initialize()
        self.main_widget.compute_initial_position(0, 0,
                                                  self.main_widget.min_width,
                                                  self.main_widget.min_height)
        print str(self.main_widget)
#        print
#        for box in self.main_widget.box_list:
#            print str(box)
#
#        print
#        print

        xsize = self.main_widget.width
        ysize = self.main_widget.height

        self.area.set_size_request(xsize, ysize)

        self.win.add(self.area)
        self.area.show()
        self.win.show()


    def traingroup_window_init(self):
        close_box = BaseWidget(False, False, 12, 12, 0, 0)
        caption = BaseWidget(True, False, 177, 12, 1, 0)
        sticky_box = BaseWidget(False, False, 12, 12, 0, 0)

        title = HBox([close_box, caption, sticky_box])

        #rows = [title]

        # left column
        left_rows = []
        left_rows.append(BaseWidget(True, False, 200, 12, 0, 0))
        left_rows.append(BaseWidget(True, False, 49, 12, 1, 0)) # 'all trains'
        left_rows.append(BaseWidget(True, False, 90, 12, 1, 0)) # 'ungrouped trains'

        left_matrix = BaseWidget(False, False, 189, 9*12, 0, 12)
        left_scroll = BaseWidget(False, True, 12, 36, 0, 1)
        matrix_row = HBox([left_matrix, left_scroll])
        left_rows.append(matrix_row)

        botleft_row = []
        botleft_row.append(BaseWidget(False, False, 24, 24, 0, 0))
        botleft_row.append(BaseWidget(False, False, 24, 24, 0, 0))
        botleft_row.append(BaseWidget(False, False, 24, 24, 0, 0))
        botleft_row.append(BaseWidget(True, True, 1, 1, 0, 0))
        botleft_row.append(BaseWidget(False, False, 24, 24, 0, 0))
        left_rows.append(HBox(botleft_row))

        left_col = VBox(left_rows)

        # Right row

        sortby = BaseWidget(False, False, 80, 12, 0, 0)
        number = BaseWidget(False, False, 154, 12, 0, 0)
        down = BaseWidget(False, False, 12, 12, 0, 0)
        resizable = BaseWidget(True, True, 0, 0, 1, 0)
        right_rows = [HBox([sortby, number, down, resizable])]

        big_block = BaseWidget(True, False, 200, 6*24, 1, 24)
        right_scroll = BaseWidget(False, True, 12, 36, 0, 1)
        right_rows.append(HBox([big_block, right_scroll]))

        avail = BaseWidget(False, False, 105, 12, 0, 0)
        manage = BaseWidget(False, False, 105, 12, 0, 0)
        down = BaseWidget(False, False, 12, 12, 0, 0)
        stop = BaseWidget(False, False, 12, 12, 0, 0)
        go = BaseWidget(False, False, 12, 12, 0, 0)
        resizable = BaseWidget(True, True, 0, 0, 1, 0)
        resizebox = BaseWidget(False, False, 12, 12, 0, 0)
        right_rows.append(HBox([avail, manage, down, stop, go, resizable, resizebox]))

        right_col = VBox(right_rows)

        return VBox([title, HBox([left_col, right_col])])


        return title

    def news_window_init(self):
        """
        Initialize the widgets
        """
        close_box = BaseWidget(False, False, 11, 12, 0, 0)
        caption = BaseWidget(True, False, 91, 12, 1, 0)

        title = HBox([close_box, caption])

        rows = [title]

        rows.append(BaseWidget(True, False, 160, 12, 0, 0))

        for length in [212, 236, 112, 112, 133, 90, 275, 292, 178, 210, 69,
                       149, 49, 103]:

            lft_but = BaseWidget(False, False, 9, 12, 0, 0)
            middle = BaseWidget(False, False, 76, 12, 0, 0)
            rgt_but = BaseWidget(False, False, 9, 12, 0, 0)
            text = BaseWidget(True, False, length, 12, 0, 0)

            row = HBox([lft_but, middle, rgt_but, text])
            rows.append(row)

        rows.append(BaseWidget(True, False, 6, 6, 0, 0))

        drop = BaseWidget(False, False, 83, 12, 0, 0)
        down = BaseWidget(False, False, 11, 12, 0, 0)
        text = BaseWidget(True, False, 255, 12, 0, 0)
        row = HBox([drop, down, text])
        rows.append(row)

        but = BaseWidget(False, False, 94, 12, 0, 0)
        text = BaseWidget(True, False, 219, 12, 0, 0)
        row = HBox([but, text])
        rows.append(row)

        rows.append(BaseWidget(True, False, 6, 6, 0, 0))

        return VBox(rows)



    def expose(self, widget, event):
        drawable = self.area.window
        colormap = self.area.get_colormap()
        black_color = colormap.alloc_color(red=0, green=0, blue=0)
        blackgc = drawable.new_gc(foreground = black_color)

        self.main_widget.draw_widget(self.area.window, blackgc)
        #xsize, ysize = self.area.window.get_size()
        #print xsize, ysize
        #self.area.window.draw_line(blackgc, 0,0, xsize-1,ysize-1)
        #self.area.window.draw_line(blackgc, xsize-1,0, 0,ysize-1)



    def size_alloc_event(self, widget, alloc, data=None):
        self.main_widget.resize(alloc.x, alloc.y, alloc.width, alloc.height)

    def delete_event(self, widget, event, data = None):
        return False

    def destroy(self, widget, data = None):
        gtk.main_quit()

a = Area()
gtk.main()
