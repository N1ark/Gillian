/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

'use strict';

import * as vscode from 'vscode';
import { ProviderResult } from 'vscode';
import { activateCodeLens } from './activateCodeLens';
import { activateDebug } from './debug';
import vscodeVariables from './vscodeVariables';
import { WebviewPanel } from './WebviewPanel';

export function activate(context: vscode.ExtensionContext) {
  activateDebug(context, new DebugAdapterExecutableFactory());
  activateCodeLens(context);
}

export function deactivate() {
  // nothing to do
}

function expandPath(s: string): string {
  if (s.startsWith('~/')) {
    s = '${env:HOME}' + s.substring(1);
  }
  return vscodeVariables(s);
}

class DebugAdapterExecutableFactory
  implements vscode.DebugAdapterDescriptorFactory
{
  // The following use of a DebugAdapter factory shows how to control what debug adapter executable is used.
  // Since the code implements the default behavior, it is absolutely not neccessary and we show it here only for educational purpose.

  createDebugAdapterDescriptor(
    _session: vscode.DebugSession,
    executable: vscode.DebugAdapterExecutable | undefined
  ): ProviderResult<vscode.DebugAdapterDescriptor> {
    const fileExtension = _session.configuration.program.split('.').pop();
    let langCmd: string;
    // Match of the file extension first
    switch (fileExtension) {
      case 'c':
        langCmd = 'gillian-c2';
        break;
      case 'js':
        langCmd = 'gillian-js';
        break;
      case 'wisl':
        langCmd = 'wisl';
        break;
      case 'gil':
        // Check the target language if it is a GIL file
        switch (_session.configuration.targetLanguage) {
          case 'js':
            langCmd = 'gillian-js';
            break;
          case 'c':
            langCmd = 'gillian-c';
            break;
          case 'c2':
            langCmd = 'gillian-c2';
            break;
          case 'wisl':
          default:
            // Default to WISL
            langCmd = 'wisl';
            break;
        }
        break;
      default:
        // Default to WISL
        langCmd = 'wisl';
        break;
    }

    const config = vscode.workspace.getConfiguration('gillianDebugger');
    const langConfig = vscode.workspace.getConfiguration(
      `gillianDebugger.${langCmd}`
    );
    console.log('Configuring debugger...', { config });

    const workspaceFolder =
      vscode.workspace.workspaceFolders?.[0]?.uri?.fsPath || '.';
    const extraArgs: string[] = (langConfig.commandLineArguments || []).map(
      (arg: string) => arg.replace('${workspaceFolder}', workspaceFolder)
    );

    const mode = _session.configuration.execMode || 'debugverify';

    const env = langConfig.environmentVariables || {};
    let args = [mode, '-r', 'db', ...extraArgs];
    if (config.useManualProof) {
      args.push('-m');
    }
    let cmd: string;
    let cwd: string;

    if (config.runMode === 'installed') {
      cwd = expandPath(config.outputDirectory || './.gillian');
      const binDirectory = config.binDirectory;
      const path = binDirectory ? expandPath(binDirectory) + '/' : '';
      vscode.workspace.fs.createDirectory(vscode.Uri.file(cwd));
      cmd = `${path}${langCmd}`;
    } else {
      let sourceDirectory = config.sourceDirectory;
      if (!sourceDirectory)
        throw 'Please specify the location of Gillian source code';
      sourceDirectory = expandPath(sourceDirectory);
      cwd = sourceDirectory;
      cmd = 'opam';
      args = ['exec', '--', 'dune', 'exec', '--', langCmd].concat(args);
    }

    console.log('Starting debugger...', { cmd, args, cwd });
    WebviewPanel.currentPanel?.clearState();
    const options = { cwd, env };
    executable = new vscode.DebugAdapterExecutable(cmd, args, options);

    // make VS Code launch the DA executable
    return executable;
  }
}
