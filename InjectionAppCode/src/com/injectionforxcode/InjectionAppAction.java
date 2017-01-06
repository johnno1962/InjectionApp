package com.injectionforxcode;

import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.PlatformDataKeys;
import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.ui.Messages;
import com.intellij.util.ui.UIUtil;

/**
 * Copyright (c) 2013 John Holdsworth. All rights reserved.
 *
 * Created with IntelliJ IDEA.
 * Date: 05/01/2016
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * If you want to "support the cause", consider a paypal donation to:
 *
 * injectionforxcode@johnholdsworth.com
 *
 */

public class InjectionAppAction extends AnAction {

    public void actionPerformed(AnActionEvent event) {
        Project project = event.getData(PlatformDataKeys.PROJECT);
        VirtualFile vf = event.getData(PlatformDataKeys.VIRTUAL_FILE);
        if ( vf == null )
            return;

        FileDocumentManager.getInstance().saveAllDocuments();
        try {
            Runtime.getRuntime().exec(new String[]{"/Applications/Injection.app/Contents/Resources/injectSource",
                    vf.getCanonicalPath()}, null, null).waitFor();
        }
        catch ( final Exception e ) {
            UIUtil.invokeAndWaitIfNeeded(new Runnable() {
                public void run() {
                    Messages.showMessageDialog(e.getMessage(), "InjectionApp Plugin", Messages.getInformationIcon());
                }
            } );
        }
    }

}
