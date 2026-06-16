# emacs-term-toggle

## About

![Screenshot:](term-toggle.png)

Term-toggle lets you quickly toggle shells that come built-in with Emacs. Currently it can toggle shell, term, ansi-term, eshell, and ielm. You can put each one on a keyboard shortcut and toggle a console off and on as needed. The console will be
opened in the current buffer's default directory. This applicaiton is similar to [shell-pop](https://github.com/kyagi/shell-pop-el), but this one lets you have different terminals open at once, while shell-pop works only on pre-defined
one. I like to be able to work both with ielm/eshell and open a terminal from time to time, so I don't want to have just one pre-defined terminal I can pop back and forth. Term-toggle is also much lighter in resource usage and with somewhat
less features than shell-pop. Most notably you can't easily add your own shell via an API, but it is so small, so you can easily hack it in :). 

It is al about cnvenicence and minimalism. I personally really care only about eshell, term and ielm, and wish to be able to toggle them on and off quickly. When I wish to kill a term, I don't want to answer y-or-no questions, so it has
features to quickly kill buffer or it's process.

## Features

 - very minimalistic and light on resources
 - multiple shells out of the box
 - automatically exit process when console buffer is killed
 - automatically kill buffer and its window when shell is exited

## Install

For the moment this is not in any package repository. You can download it from the git repo and install with package.el with

    M-x package-install-file RET 

alternatively, if you are using Emacs 29.0 and later, you can install via package-vc, directly from the remote repo. See the Emacs manual for use-package and package-vc.

I will see if they would like to have it in Melpa.

Alternatively you may install it manually by adding term-toggle.el to your load path and either generating autoloads, or require term-toggle.el when Emacs starts.

## Usage

Bind `term-toggle' and `term-toggle-eshell' to keys of your choice, for example:

    (define-key global-map [S-f2] #'term-toggle-ansi)
    (define-key global-map [f2] #'term-toggle-eshell)

We this setup you can press F2 to toggle eshell, or S-F2 to open anis-term, when you press it again it will go away.

The term/eshell buffer will not get killed, just burried down so they are not in the way.

Once you are done with using eshell or term, you can simply kill buffer to get rid of them. As a convenience, you can customize option to no confirm exit, so you don't need to confirm exit from the term because of the live bash process:

    (setq term-toggle-no-confirm-exit t)

Optionally you can also customize option to kill-buffer and exit terminal window when shell process has exited:

    (setq term-toggle-kill-buffer-on-term-exit t)

This way, if you press Ctrl+D in you shell window, term buffer and window will be killed too.

## History

Derived from [Joseph's](https://www.emacswiki.org/emacs/term-toggle.el), this plugin brings up a quake-style console with commands term-toggle{,-cd}. The major difference with Joseph's version is that maximized console feature is removed
(in the original version sometimes it gets stuck in maximized state, possibly because the window configuration is corrupted). Also, this plugin determines whether to split a new window for the console, or replace the buffer of current
selected window if height is not enough for a split. Another feature is that this plugin will detect the status of the terminal. When there's no process running in *terminal* buffer, it will fire up another one.

Added to [Yatao's version](https://github.com/v-yadli/emacs-term-toggle) is ability to open eshell console in current buffers as well as the option `term-toggle-no-confirm-exit' to let Emacs exit term buffer and kill bash process without confirmation.

## Licence
  
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.

