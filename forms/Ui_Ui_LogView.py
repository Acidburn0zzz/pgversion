# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file '/home/hdus/dev/qgis/pgversion-plugin/pgversion/forms/Ui_LogView.ui'
#
# Created: Thu Feb  4 16:08:06 2016
#      by: PyQt4 UI code generator 4.10.4
#
# WARNING! All changes made in this file will be lost!

from PyQt4 import QtCore, QtGui

try:
    _fromUtf8 = QtCore.QString.fromUtf8
except AttributeError:
    def _fromUtf8(s):
        return s

try:
    _encoding = QtGui.QApplication.UnicodeUTF8
    def _translate(context, text, disambig):
        return QtGui.QApplication.translate(context, text, disambig, _encoding)
except AttributeError:
    def _translate(context, text, disambig):
        return QtGui.QApplication.translate(context, text, disambig)

class Ui_LogView(object):
    def setupUi(self, LogView):
        LogView.setObjectName(_fromUtf8("LogView"))
        LogView.setWindowModality(QtCore.Qt.ApplicationModal)
        LogView.resize(722, 582)
        self.gridLayout = QtGui.QGridLayout(LogView)
        self.gridLayout.setObjectName(_fromUtf8("gridLayout"))
        self.splitter = QtGui.QSplitter(LogView)
        self.splitter.setOrientation(QtCore.Qt.Horizontal)
        self.splitter.setObjectName(_fromUtf8("splitter"))
        self.btnRollback = QtGui.QPushButton(self.splitter)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Expanding, QtGui.QSizePolicy.Fixed)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.btnRollback.sizePolicy().hasHeightForWidth())
        self.btnRollback.setSizePolicy(sizePolicy)
        self.btnRollback.setMinimumSize(QtCore.QSize(0, 0))
        self.btnRollback.setMaximumSize(QtCore.QSize(16777215, 16777215))
        self.btnRollback.setObjectName(_fromUtf8("btnRollback"))
        self.gridLayout.addWidget(self.splitter, 1, 1, 1, 1)
        self.treeWidget = QtGui.QTreeWidget(LogView)
        self.treeWidget.setObjectName(_fromUtf8("treeWidget"))
        self.gridLayout.addWidget(self.treeWidget, 2, 0, 1, 2)
        self.btnClose = QtGui.QDialogButtonBox(LogView)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Maximum, QtGui.QSizePolicy.Fixed)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.btnClose.sizePolicy().hasHeightForWidth())
        self.btnClose.setSizePolicy(sizePolicy)
        self.btnClose.setStandardButtons(QtGui.QDialogButtonBox.Close)
        self.btnClose.setObjectName(_fromUtf8("btnClose"))
        self.gridLayout.addWidget(self.btnClose, 3, 1, 1, 1)
        self.btnDiff = QtGui.QPushButton(LogView)
        self.btnDiff.setObjectName(_fromUtf8("btnDiff"))
        self.gridLayout.addWidget(self.btnDiff, 0, 1, 1, 1)

        self.retranslateUi(LogView)
        QtCore.QMetaObject.connectSlotsByName(LogView)

    def retranslateUi(self, LogView):
        LogView.setWindowTitle(_translate("LogView", "PG-Version LogView", None))
        self.btnRollback.setText(_translate("LogView", "rollback to selected revision", None))
        self.treeWidget.headerItem().setText(0, _translate("LogView", "Revision", None))
        self.treeWidget.headerItem().setText(1, _translate("LogView", "Date", None))
        self.treeWidget.headerItem().setText(2, _translate("LogView", "User", None))
        self.treeWidget.headerItem().setText(3, _translate("LogView", "Log-Message", None))
        self.btnDiff.setText(_translate("LogView", "diff to selected revision", None))


if __name__ == "__main__":
    import sys
    app = QtGui.QApplication(sys.argv)
    LogView = QtGui.QDialog()
    ui = Ui_LogView()
    ui.setupUi(LogView)
    LogView.show()
    sys.exit(app.exec_())

