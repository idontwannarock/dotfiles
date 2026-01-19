" ============================================================================
" 跨平台通用 .vimrc - 強制使用 ~/.vim 目錄 (Windows/Mac/Linux 共用一份檔)
" ============================================================================

" 強制關閉 vi 相容模式（跨平台必備）
set nocompatible

" ============================================================================
" 自動安裝 vim-plug（如果不存在）
"   - Mac/Linux：用 curl 下載
"   - Windows：優先用 curl（Git Bash / Scoop 常有），沒有的話用 PowerShell
" ============================================================================
let s:plug_path = expand('~/.vim/autoload/plug.vim')

if empty(glob(s:plug_path))
  let s:plug_url = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

  if has('win32') || has('win64')
    " Windows 嘗試 curl（Git Bash 環境最常見）
    if executable('curl')
      silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs ' . s:plug_url
    else
      " 改用 PowerShell 下載（Windows 原生，幾乎都有）
      silent execute '!powershell -Command "New-Item -ItemType Directory -Force -Path ' . expand('~/.vim/autoload') . ' | Out-Null; Invoke-WebRequest -Uri ' . s:plug_url . ' -OutFile ' . s:plug_path . '"'
    endif
  else
    " Mac / Linux 用 curl
    silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs ' . s:plug_url
  endif

  " 安裝完自動執行 PlugInstall 並重新載入設定
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" ============================================================================
" 平台差異處理：強制讓 Windows 也優先使用 ~/.vim （而非 ~/vimfiles）
"   - 把 ~/.vim 加到 runtimepath 最前面
"   - 這樣所有插件、autoload、ftplugin 等都從 ~/.vim 讀取
" ============================================================================
if has('win32') || has('win64')
  " Windows 預設用 ~/vimfiles，我們強制優先 ~/.vim
  set runtimepath^=~/.vim
  " 也處理 after/ 目錄（後載入的覆蓋用）
  set runtimepath+=~/.vim/after
endif

" ============================================================================
" 你的基本設定（可自行擴充）
" ============================================================================
set number                  " 顯示行號
set relativenumber          " 相對行號（超好用！）
set fileencodings=utf-8,ucs-bom,latin1
set termencoding=utf-8
set encoding=utf-8

" Leader 鍵設為空白（很常見的設定）
let mapleader = ' '

" ============================================================================
" vim-plug 插件管理區塊（所有插件都放在這裡）
"   - 統一用 ~/.vim/plugged 目錄（跨平台一致）
" ============================================================================
call plug#begin('~/.vim/plugged')

" 你的 EasyMotion 插件
Plug 'easymotion/vim-easymotion'

" 未來想加其他插件，就直接加在這裡，例如：
" Plug 'preservim/nerdtree'
" Plug 'tpope/vim-fugitive'

call plug#end()

" ============================================================================
" EasyMotion 專屬設定
" ============================================================================
let g:EasyMotion_do_mapping = 0     " 關閉預設 mapping
let g:EasyMotion_smartcase = 1      " 智慧大小寫

" 用 <Leader>s 觸發雙字元跳轉（推薦，平均最舒服）
nmap <Leader>s <Plug>(easymotion-overwin-f2)
" 單字元跳轉（如果你喜歡更快速）
" nmap <Leader>s <Plug>(easymotion-overwin-f)

" JK 快速上下移動（可選，註解掉就不用）
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)
" ============================================================================
" 其他自訂設定（可繼續加在這裡）
" ============================================================================
" 例如：顏色主題、縮排、搜尋高亮等
" syntax on
" set hlsearch
" set ignorecase smartcase
" ...

" 結束！存檔後重新開 Vim，第一次會自動安裝插件
