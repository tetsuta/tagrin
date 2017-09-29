#!/usr/bin/wish8.4

#!/bin/sh
# the next line restarts using wish \
# exec wish8.0jp "$0" "$@"

# ======================================================================
# Name: tagrin.tcl
# Version: 1.1
# Maintener: Takahashi Tetsuro / t_taka@pluto.ai.kyutech.ac.jp
# Id: $Id: tagrin.tcl,v 1.123.2.179 2006/06/30 10:36:01 tetsu Exp $
# Purpose: Tagging
# ======================================================================

# package require idrTclObject 1.0

# ToDo
# search --> data_idを使っている
# export


# ============================================================
##############################
# idrTclObjects
# copyright 2001-2002 ideaResources, LLC
# written by Salvatore Sorrentino
# this software may be used freely
# so long as the original copyright appears
# in the header and all modifications are documented.
# 
# version 1.01 fixed non-persistent objects
# --------also allows an object to destroy itself form within itself
# 
##############################

package provide idrTclObject 1.0

namespace eval idrTclObjects {

	variable objCount 0
	variable garbageList [list]
	variable parentedGarbage
	variable properties
	
	variable collection [after 5000 {idrTclObjects::collectGarbage}]
	namespace export objCount collectGarbage
	proc collectGarbage {} {
		variable garbageList
		variable collection
		after idle {}
		foreach i $garbageList {
			catch {unobject $i}
		}
		after cancel $collection
		set garbageList [list]
		set collection [after 60000 {idrTclObjects::collectGarbage}]
	}
	
	proc __setShared__ {initer obj prop master isarray com} {
		if {$com == "w"} {
			if {$isarray == {}} {
				set ${obj}::${prop} [subst \$[subst ${initer}::${prop}]]
			} else {
				set ${obj}::${prop}($isarray) [subst \$[subst ${initer}::${prop}($isarray)]]
			}
		} elseif {$com == "u"} {
			if {$isarray == {}} {
				unset ${obj}::${prop}
			} else {
				array unset ${obj}::${prop} $isarray
			}	
		}
	}
	
	proc __accessProperties__ {obj __objname__} {
		foreach prop $idrTclObjects::properties($obj) {
			namespace inscope $__objname__ variable $prop
			if {[array exists ${obj}::${prop}]} {
				foreach arr [array names ${obj}::${prop}] {
					set ${__objname__}::${prop}($arr) [subst \$[subst ${obj}::${prop}($arr)]]
				}
			} elseif {[info exists ${obj}::${prop}]} {
				set ${__objname__}::$prop [subst \$[subst ${obj}::${prop}]]
			}
			trace variable ${__objname__}::${prop} w "idrTclObjects::__setShared__ $__objname__ $obj $prop"
			trace variable ${obj}::${prop} w "idrTclObjects::__setShared__ $obj $__objname__ $prop"
			
			trace variable ${__objname__}::${prop} u "idrTclObjects::__setShared__ $__objname__ $obj $prop"
			trace variable ${obj}::${prop} u "idrTclObjects::__setShared__ $obj $__objname__ $prop"
			
		}
	}
	
	proc doUnobject {objs} {
		foreach obj $objs {
			foreach parented [array names idrTclObjects::parentedGarbage *$obj*] {
				catch {namespace delete $idrTclObjects::parentedGarbage($parented)}
				catch {array unset idrTclObjects::parentedGarbage $parented}
			}
			namespace delete $obj
		}
	}
}

######################
# start global namespace procedures


# defines an object
proc object {name body} {
	set ::idrTclObjects::procList($name) $body
}

# a utility for creating uniquely named Tk widgets
proc unique {cmd name args} {
	incr ::idrTclObjects::objCount
	eval "$cmd $name$::idrTclObjects::objCount [join $args]"
	return $name$::idrTclObjects::objCount
}

# removes a defined object from memory, including it's children
proc unobject {args} {
	set x [after idle [list idrTclObjects::doUnobject $args]]
}


		
# instantiates a defined object in the calling object, or in the global namespace (if called from the global namespce)
proc new {obj {name {}} {persist {0}}} {
	set initial $name
	incr ::idrTclObjects::objCount
	if {$name == {}} {
		set name "object$::idrTclObjects::objCount"
	}
	
	######################
	# start object procedures
	# creates new namespace and initializes its object procedures
	namespace eval [namespace current]::$name {
		variable __objname__
		# declares an exportable procedure
		set __objname__ [namespace current]
		set idrTclObjects::properties($__objname__) [list]
		set ${__objname__}::__setting__ 0
		proc property {n} {
			variable __objname__
			namespace inscope $__objname__ variable $n
			
			if {[lsearch $idrTclObjects::properties($__objname__) $n] < 0} {
				lappend idrTclObjects::properties($__objname__) $n
			}
		}
		
		
		
		
		proc public {args} {
			eval "proc $args"
			namespace export [lindex $args 0]
		}
		
		# declares an non-exportable procedure
		proc private {args} {
			eval "proc $args"
		}
		
		# imports exportable procedures from the parent object
		proc inherit {args} {
			variable __objname__
			foreach arg $args {
				namespace import [namespace parent]::$arg
				idrTclObjects::__accessProperties__ [namespace parent] $__objname__
			}
		}
		
		# imports exportable procudures from a pre-existing defined object
		proc latch {args} {
			variable __objname__
			foreach arg $args {
				namespace import ::${arg}::*
				idrTclObjects::__accessProperties__ ::${arg}
			}
		}
		
		# returns a reference to the current object or runs a procedure in the current object
		proc this {args} {
			if {$args == {}} {
				return [namespace current]
			} else {
				eval [namespace current]::$args
			}
		}
		
		# returns a reference to the parent object or runs a procedure in the parent object
		proc ancestor {args} {
			if {$args == {}} {
				return [namespace parent]
			} else {
				eval [namespace parent]::$args
			}
		}
		
		# imports exportable procudures from a non-existing defined object, and creates the defined object provides a good layer of abstraction
		proc import {args} {
			variable __objname__
			foreach arg $args {
				set x [new $arg {} 1]
				namespace import ::${x}::*
				set idrTclObjects::parentedGarbage([namespace current],$x) $x
				idrTclObjects::__accessProperties__ ::$x $__objname__
			}
		}
	}
	# end object procedures
	######################
	

	namespace eval [namespace current]::$name [list eval $::idrTclObjects::procList($obj)]
	if {$initial == {} && $persist == 0} {
		lappend idrTclObjects::garbageList $name
	}
	return $name
}

# end global namespace procedures
# ============================================================


### DefaultConf ###
proc DefaultConf {} {
    global data tagdata binding w sysconf

    # ウインド内の要素の配置 (flat:1 / 2段:0)
    #   小さいモニタを使っている場合は 0がよい
    set w(flat-layout) 1

    # スクリーン上での，一行内の最大の文字数
    set data(max-char-in-line) 10000

    # スクリーンのサイズ
    set w(screen-height) 20
    set w(screen-width) 80

    # ミニスクリーン (on:1 / off:0)
    set w(mini-screen-on) 0
    set w(mini-screen-height) 5

    # タグの情報を標準出力に出すボタンを使うかどうか(使わない:0 / 使う:1)
    set w(stdout-button) 0

    # スクリーン上での行間
    set w(screen-baseline) 3

    # スクリーンの色
    set w(background) white
    set w(foreground) black

    # フォント
    set w(font) k14
    #set w(font) {{ＭＳ ゴシック} 12 normal}

    # テキストフォント
    set w(textfont) k14
    # set w(textfont) {{ＭＳ Ｐゴシック} 12 normal}

    # (true/false)形式のタグをふる属性のリスト
    set data(atrb-tf-list) {自信なし}

    # text形式のタグをふる属性のリスト
    set data(atrb-text-list) {終了}

    # 使うタグの行数
    set tagdata(tag-list-num) 3

    # 使うタグのリスト
    set tagdata(tag-list1) {t1 t2}
    set tagdata(tag-list2) {s1 s2}
    set tagdata(tag-list3) {u1 u2}

    # 色をつける順序．リスト中の後の方が上にくる．
    set tagdata(link-order) {t1 t2 s1 s2 linked-tag neighbor-tag current-tag sel}

    # マウスが上に来たときにハイライトするリスト
    set tagdata(cand-hilight-list) {}
#     set tagdata(cand-hilight-np) {述語 照応詞}
#     set tagdata(cand-hilight-機能語相当) {述語}

    # ハイライトする枠の幅
    set tagdata(cand-hilight-width) 3

    # リンク元となるタグのリスト
    set tagdata(link-from-list) {t1 t2}

    # リンク先のタグのリスト
    set tagdata(link-tag-list) {s1 s2}

    # 再帰的にハイライトする
    set tagdata(hilight-current-recursively) {}

    # 再帰的にハイライトする
    # さらに，別のタグの係り先となった場合にもハイライトされる
    # tagdata(hilight-current-recursively)の機能を包含する
    set tagdata(hilight-link-recursively) {s1}

    # 有向リンクの順方向にのみにハイライトする．
    # デフォルトは無向リンクとしてハイライトされるが，ここで指定することにより
    # 有向リンクとして扱われる
    set tagdata(hilight-directed-link-list) {s1}


    # ここで指定されたリンク元について，属性のidが同じであれば
    # ハイライトする．
    set tagdata(hilight-same-id-list) {照応詞}

    # 焦点を当てているタグの隣のタグの色
    set tagdata(hilight-link-list-neighbor-fg) Black
    set tagdata(hilight-link-list-neighbor-bg) orangered

    # 2つ以上離れた個所のタグの色
    set tagdata(hilight-link-list-fg) black
    set tagdata(hilight-link-list-bg) darkorange


    # リンク元となるタグの文字色と背景色
    set tagdata(link-from-color) Black
    set tagdata(link-from-background-color) red

    # 使う色のリスト
    set tagdata(color-list) {Black Gray Purple Blue Green Red Pink Orange White Navy Yellow Sienna SkyBlue Magenta DarkGreen firebrick Grey}

    # 各タグの設定
    set tagdata(t1-status) 1
    set tagdata(t1-fcolor) LightBlue2
    set tagdata(t1-bcolor) Black
    set tagdata(t1-bind) P
    # t2
    set tagdata(t2-status) 1
    set tagdata(t2-fcolor) purple
    set tagdata(t2-bcolor) Black
    set tagdata(t2-bind) Q
    # s1
    set tagdata(s1-status) 1
    set tagdata(s1-fcolor) lightgreen
    set tagdata(s1-bcolor) Black
    set tagdata(s1-bind) p
    # s2
    set tagdata(s2-status) 1
    set tagdata(s2-fcolor) "olive drab"
    set tagdata(s2-bcolor) Black
    set tagdata(s2-bind) q
    # u1
    set tagdata(u1-status) 1
    set tagdata(u1-fcolor) yellow
    set tagdata(u1-bcolor) Black
    set tagdata(u1-bind) K
    # u2
    set tagdata(u2-status) 1
    set tagdata(u2-fcolor) orange
    set tagdata(u2-bcolor) Black
    set tagdata(u2-bind) k

#    set tagdata(u2) 1

    # ファイルのオープン
    set binding(OpenFile) Control-o

    # 上書き保存
    set binding(Save) Control-s

    # 上書きエクスポート
    set binding(Export) Alt-x

    # タグの除去
    set binding(RemoveTag) Control-r

    # 再表示
    set binding(Reflesh) Control-l

    # 元に戻す
    set binding(Undo) Control-z

    # フォーカスをテキストエントリから外す
    set binding(Unfocus) Escape

    # ID検索
    set binding(ISearch) Control-i

    # テキスト検索
    set binding(TSearch) Control-f

    # 終了(自動保存はされない)
    set binding(exit) Control-q

    # 警告の文字色と背景色
    set tagdata(warnning-fg-color) Black
    set tagdata(warnning-bg-color) Pink

    # マークされたタグ名の背景をハイライトする色
    set tagdata(marked-tag-color) lightgreen
    set tagdata(from-tag-color) ivory
    set tagdata(to-tag-color) pink

    # タギングモードと編集モードのトグル
    set binding(ToggleEditMode) Control-t

    # テキストへの変更の保存
    set binding(ResetText) Control-m

    # オートセーブ(0:しない/1:する)
    set sysconf(autosave) 1

    # ステータスボタン(0:付けない/1:付ける)
    set sysconf(status_bar) 0

    # タグボタンの動作(0:タグ付与/1:タグ除去)
    set sysconf(tagbutton) 0

    # ------------------------------
    # system only

    # モード
    set w(edit-mode) 0

    # 現在対象としてるタグからフォーカスを外す
    set w(unfocus) 0
}


# ======================================================================
# ======================================================================
#                 Don't touch under this line!!
# ======================================================================
# ======================================================================


### Main ###
proc Main {} {
    global w file tagdata screens
    wm title . "Tagrin"

    tk useinputmethods 1
    DefaultConf
    SetConf
    MakeHeader
    MakeAttribute
    MakeScreen
    SetBinding
    MakePopupMenu
    MakeStatusBar
    MakeTag
    SetTagBind
    Initialize
#    SelectImport
#     exit
}


### Object ###
# ================================================== #
#  document
# ================================================== #
object document {
    # list of record
    property records
    # integer
    property current_index
    # レコードの数
    property num
    # テキスト検索にマッチしたレコードの indexのリスト
    property matched_record_list
    # テキスト検索時のインデックス
    property matched_index

# ------------------------------
# construct --> object
# ------------------------------
    public construct {} {
	variable records
	variable current_index
	variable num
	variable matched_record_list
	variable matched_index

	set records [list]
	set current_index 0
	set num 0
	set matched_record_list [list]
	set matched_index 0
	return [this]
    }

# ------------------------------
# replace_record --> 1
# レコードリストの中の現在見ているレコードを，引数で与えたレコードと入れ換える．
# ------------------------------
    public replace_record {new_record} {
	variable records
	variable current_index

	set records \
	    [lreplace $records $current_index $current_index $new_record]

	return 1
    }

# ------------------------------
# previous
# current_indexの値を 1つ前のレコードにセットする
# ------------------------------
    public previous {} {
	variable current_index
	variable num
	if {$current_index == 0} {
	    set current_index [expr $num - 1]
	} else {
	    incr current_index -1
	}
    }

# ------------------------------
# next
# current_indexの値を 1つ後のレコードにセットする
# ------------------------------
    public next {} {
	variable current_index
	variable num
	if {$current_index == [expr $num - 1]} {
	    set current_index 0
	} else {
	    incr current_index
	}
    }

# ------------------------------
# append_record record --> list of record
# 引数で与えたレコードを record listに追加する
# ------------------------------
    public append_record {args} {
	variable records
	variable num
	lappend records [lindex $args 0]
	incr num
	return $records
    }


# ------------------------------
# current_id --> current id
# 現在見ているレコードの IDを返す
# ------------------------------
    public current_id {} {
	return [[[this]::current_record]::id]
    }


# ------------------------------
# get_records --> list of record
# record listを返す
# ------------------------------
    public get_records {} {
	variable records
	return $records
    }

# ------------------------------
# current_record --> current record
# 現在見ているレコードを返す．
# ------------------------------
    public current_record {} {
	variable current_index
	variable records
	return [lindex $records $current_index]
    }

# ------------------------------
# num --> num
# レコードの数を返す
# ------------------------------
    public num {} {
	variable num
	return $num
    }


# ------------------------------
# print [file-stream]
# 各レコードについて，printを呼ぶ
# streamが指定されれば，その streamに出力する
# ------------------------------
    public print {args} {
	variable records

	foreach record $records {
	    ${record}::print $args
	}
    }


# ------------------------------
# export [file-stream]
# 各レコードについて，exportを呼ぶ
# streamが指定されれば，その streamに出力する
# ------------------------------
    public export {args} {
	variable records

	foreach record $records {
	    SetData
	    ${record}::export $args
	    [this]::next
	}

    }


# ------------------------------
# text_search flag -> 1(success) or 0(fail)
# textで検索を行い，見付けたレコードを表示する
# ------------------------------
    public text_search {flag} {
	variable records
	variable current_index
	variable num
	variable matched_record_list
	variable matched_index
	global data
	
	set pattern $data(search-pattern)
	switch -exact $flag {
	    first {
		# 検索にヒットしたレコードが入る
		set matched_record_list [list]
		if { [string match $pattern "" ] } {
		    Message "Pattern is empty."
		    return 0
		}
		set start_index $current_index
		for {set sindex $start_index} {$sindex < $num} {incr sindex} {
		    if [[lindex $records $sindex]::text_match $pattern] {
			lappend matched_record_list $sindex
		    }
		}
		if {[llength $matched_record_list] == 0} {
		    Clear
		    SetStatus "Not found"
		    return 0
		} else {
		    set matched_index 0
		    set current_index [lindex $matched_record_list $matched_index]
		    SetData
		    SearchedHilight $pattern
		    SetStatus "Search..."
		    return 1
		}
	    }
	    next {
		incr matched_index
		if {$matched_index < [llength $matched_record_list)]} {
		    set current_index [lindex $matched_record_list $matched_index]
		    SetData
		    SearchedHilight $pattern
		    SetStatus "Next record"
		    return 1
		} else {
		    SetStatus "No more record"
		    incr matched_index -1
		}
	    }
	    previous {
		incr matched_index -1
		if {$matched_index >= 0} {
		    set current_index [lindex $matched_record_list $matched_index]
		    SetData
		    SearchedHilight $pattern
		    SetStatus "Next record"
		    return 1
		} else {
		    SetStatus "No more record"
		    incr matched_index
		}
	    }
	}
    }	


# ------------------------------
# idsearch -> 1(success) or 0(fail)
# IDや Indexで検索を行い，見付けたレコードを表示する
# ------------------------------
    public idsearch {feature val} {
	global data w
	variable current_index
	variable num

	switch -exact $feature {
	    id {
		set index 0
		foreach record [[this]::get_records] {
		    if [regexp $data(id) [${record}::id]] {
 			set current_index $index
			SetData
			return 1
		    }
		    incr index
		}
		Message "Unknown ID"
		return 0
	    }
	    index {
		SetData
		return 1
	    }

	    # 複数の条件を入力できるようにしなければならない
	    # 検索結果の次が見れない
	    tf_attrib {
		set index 0
		foreach record [[this]::get_records] {
		    if {[${record}::get_attribute $val] == 1} {
			set current_index $index
			SetData
			return 1
		    }
		    incr index
		}
	    }

	    # 複数の条件を入力できるようにしなければならない
	    # 検索結果の次が見れない
	    text_attrib {
		set pattern [$w(atrb).text.${val}.entry get]
		set index 0
		foreach record [[this]::get_records] {
		    if {[string match $pattern [${record}::get_attribute $val]]} {
			set current_index $index
			SetData
			return 1
		    }
		    incr index
		}
	    }
	}
    }
}



# ================================================== #
#  record
# ================================================== #
object record {
    # string(今は integer)
    property id
    # string
    property contents
    # array of TAG
    property tags
    # array
    property attribute
    # integer
    property max_tag_id
    # integer：現在見ている tagの ID
    property current_id
    # array : attributeのIDと タグの IDのマッピング
    property aid2id
    # integer : 新しく attribute の idを付与するときの値．
    property newtag_id
    # list : リンク元となるタグ(is_from)の idリスト
    property from_tag_list
    # list : リンク先となるタグ(is_to)の idリスト
    property to_tag_list
    # list : リンク元でもリンク先でもないタグ(is_constant)の idリスト
    property constant_tag_list
    # list : list of list {aid of link-from-id,  link-to-id} appendするときに，
    # リンク先(link-from)がまだ登録されていないときに入れる．
    property link_reserved_list
    # list: temporal
    property done_list
    # list: 再帰的にハイライトするタグのリスト
    property rec_hilight_tag_list
    # list: [tagname, from, to] 現在選択しているタグの情報
    # マウスで選択したときに一つめだけをハイライトするように，
    # また，タブで選択したときに同じ場所のタグをハイライトしないように
    property current_selected_tag

# ------------------------------
#     construct id --> object
# ------------------------------
    public construct {args} {
	variable id
	variable contents
	variable tags
	variable attribute
	variable max_tag_id
	variable current_id
	variable newtag_id
	variable from_tag_list
	variable to_tag_list
	variable constant_tag_list
	variable link_reserved_list
	variable done_list
	variable rec_hilight_tag_list
	variable current_selected_tag
	global data

	set id [lindex $args 0]
	set contents ""
	set max_tag_id 0
	set current_id -1
	set newtag_id 100
	set from_tag_list [list]
	set to_tag_list [list]
	set constant_tag_list [list]
	set link_reserved_list [list]
	set done_list [list]
	set rec_hilight_tag_list [list]
	set current_selected_tag [list]

	foreach atrb $data(atrb-tf-list) {
	    set attribute($atrb) 0
	}
	foreach atrb $data(atrb-text-list) {
	    set attribute($atrb) ""
	}

	return [this]
    }


# ------------------------------
# copy record --> 1
# 引数に与えられた recordの情報をコピーする
# ------------------------------
    public copy {source_record} {
	variable id
	variable contents
	variable tags
	variable attribute
	variable max_tag_id
	variable current_id
	variable aid2id
	variable newtag_id
	variable from_tag_list
	variable to_tag_list
	variable constant_tag_list
	variable link_reserved_list
	variable done_list
	variable rec_hilight_tag_list
	variable current_selected_tag

	# 直接データをさわっており，object指向に反している
	set id [set ${source_record}::id]
	set contents [set ${source_record}::contents]
	set max_tag_id [set ${source_record}::max_tag_id]
	set current_id [set ${source_record}::current_id]
	set newtag_id [set ${source_record}::newtag_id]
	set from_tag_list [set ${source_record}::from_tag_list]
	set to_tag_list [set ${source_record}::to_tag_list]
	set constant_tag_list [set ${source_record}::constant_tag_list]
	set link_reserved_list [set ${source_record}::link_reserved_list]
	set done_list [set ${source_record}::done_list]
	set rec_hilight_tag_list [set ${source_record}::rec_hilight_tag_list]
	set current_selected_tag [set ${source_record}::current_selected_tag]

	array set attribute [array get ${source_record}::attribute]
	array set aid2id [array get ${source_record}::aid2id]

	# ここではタグのポインタだけをコピーしているので，新しく追加した
	# タグとリンクがはられているタグについては，のちのち処理が必要となる
	# たとえば，tags()で見付からなかった場合はないものと思って無視するなど．
 	array set tags [array get ${source_record}::tags]

	return 1
    }


# ------------------------------
# replace_tag tag_list
# tag_list に入っているタグを，現在持っているタグと入れかえる
# ------------------------------
    public replace_tag {args} {
	variable tags

	set tag_list [lindex $args 0]
	foreach tag $tag_list {
	    set tags([${tag}::id]) $tag
	}
    }


# ------------------------------
# set_tag_undo
# undoのためにタグをコピーする
# ------------------------------
    public set_tag_undo {args} {
	global data
	variable tags
	variable aid2id
	set tag [lindex $args 0]

	if {$data(undo-flag) == 0} {
	    return 1
	}

	set index [expr [llength $data(undo-tag-list)] - 1]
	set last_list [lindex $data(undo-tag-list) $index]

	# タグをコピーして追加する．
	set new_tag [new tag {} 1]
	${new_tag}::copy $tag
	lappend last_list $new_tag

	# リンク先を持っていたら，リンク先のタグもコピーする．
	set from_tag_aid [${tag}::get_atrb ln]
	if ![string match $from_tag_aid ""] {

	    if [info exist aid2id($from_tag_aid)] {
		# 係り先のタグが存在すれば
		set from_tag_id $aid2id($from_tag_aid)
		# 係り関係がループになっているタグを消すときには，
		# 係り先をすでに消している場合があるので NULL check
		if {$tags($from_tag_id) != "NULL"} {
		    set new_from_tag [new tag {} 1]
		    ${new_from_tag}::copy $tags($from_tag_id)
		    lappend last_list $new_from_tag
		}
	    } else {
		# 係り先のタグが存在しなければ
		# 何らかの理由で，係り先のタグが存在しない場合がある
		# その場合，リンクの情報を消す
		${tag}::remove_atrb ln
		Message "unknown linking ID $from_tag_aid"
	    }
	}

	set data(undo-tag-list) \
	    [lreplace $data(undo-tag-list) $index $index $last_list]

    }



# ------------------------------
# reset_from_tag_list --> -1 or tagid
# SetCurrentFromに呼ばれる
# 現在選択されている from-tag用に，from_tag_listを作りなおす．
# 新しい from_tag_listが値を持っていたら，その先頭を返し，持っていなかったら
# -1を返す．
# ------------------------------
    public reset_from_tag_list {} {
	variable current_id
	variable from_tag_list
	variable tags
	variable max_tag_id
	global tagdata

	set tmp_list [list]
	for {set i 0} {$i < $max_tag_id} {incr i} {
	    set tag $tags($i)
	    if {$tag == "NULL"} continue

	    if [${tag}::is_from] {
		if {[lsearch -exact $tagdata(current-from-list) [set ${tag}::name]] != -1} {
		    # タグが現在選択されている場合に追加する
		    lappend tmp_list [${tag}::id]
		}
	    }
	}
	set from_tag_list $tmp_list

	if {[llength $from_tag_list] > 0} {
	    # from_tag_listが値を持っていて，
	    if {[lsearch -exact $from_tag_list $current_id] == -1} {
		# これまでの current_idが from_tag_listに入っていなければ，先頭のタグの idを返す
		return [lindex $from_tag_list 0]
	    } else {
		# これまでの current_idも from_tag_listに入っていれば，current_idを返す
		return $current_id
	    }
	} else {
	    # from_tag_listが値を持ってなかったら，-1を返す．
	    return -1
	}
    }

# ------------------------------
# text_match string --> 0/1
# レコードの contentsが stringにマッチしたら 1を返す    
# ------------------------------
    public text_match {args} {
	variable contents
	set pattern [lindex $args 0]
	return [regexp $pattern $contents]
    }


# ------------------------------
# set_tags --> 1
# SetDataに呼ばれ，タグの情報を付与する
# mode: String = tagging/edit
# ------------------------------
    public set_tags {mode unfocus} {
	variable current_id
	variable from_tag_list
	variable to_tag_list
	variable constant_tag_list
	variable done_list
	global tagdata

	# current-from-list
	if {${unfocus} == 1} {
	    set current_id -1
	} else {
	    set current_id [[this]::reset_from_tag_list]
	}

	# current_tag
 	set current_tag [[this]::id2tag $current_id]


	# constantタグは無条件にタグを付与する
	foreach tag_id $constant_tag_list {
	    [[this]::id2tag $tag_id]::annotate
	}

	# from_tag_listのタグは無条件にタグを付与する
	foreach tag_id $from_tag_list {
	    [[this]::id2tag $tag_id]::annotate
	}

	# modeをチェック
	if {[string match $mode "edit"]} {
	    # edit modeなら，すべての toタグを付与
	    foreach tag_id $to_tag_list {
		[[this]::id2tag $tag_id]::annotate
	    }
	} else {
	    # tagging modeなら，付与するタグを選択する
	    if {![string match $current_tag NULL]} {

		# 今回つけるリンク先タグのリスト
		set current_to_tag_list [list]

		# linked tagを付与
		foreach each_to_id [set ${current_tag}::linked_list] {

		    # current_tagの linked_listに登録されてある各タグidについて
		    set each_to_tag [[this]::id2tag $each_to_id]
		    if {[string match $each_to_tag NULL]} {
			# もし，そのタグがなければ linked_listから消す
			${current_tag}::delete_linked $each_to_id
		    } else {
			# タグがあれば表示する．
			${each_to_tag}::annotate
			lappend current_to_tag_list ${each_to_tag}
		    }
		}

		# 再帰的にタグを付与
		set done_list [hilight_recursively $current_tag 0 [list]]
    		hilight_link_recursively $current_to_tag_list $done_list
  		set_same_id_tags ${current_tag}

		# current_tagの 2文字目の先にカーソルを置く
		ScreenCommand mark set insert [${current_tag}::from]
		ScreenCommand mark set anchor insert
		ScreenCommand mark set insert "insert + 1 chars"
		ScreenCommand mark set anchor "anchor + 1 chars"
	    }
	}

	foreach tag_name $tagdata(link-order) {
	    catch {ScreenCommand tag raise $tag_name}
	}

	return 1
    }


    # ------------------------------
    # hilight_link_recursively {$current_to_tag_list $done_list}
    # ------------------------------
    public hilight_link_recursively {current_to_tag_list $done_list} {
	variable from_tag_list
	variable done_list
	global tagdata

	# $tagdata(hilight-link-recursively)が空なら何もしない
	if { [llength $tagdata(hilight-link-recursively)] == 0 } {
	    return 1
	}

	# このタグを現在のレコードから集めてチェックする
	set checking_from_tag_list [list]
	foreach tag_id $from_tag_list {
	    set a_from_tag [[this]::id2tag $tag_id]
	    if {[${a_from_tag}::is_to]} {
		if { [lsearch -exact $tagdata(hilight-link-recursively) [set ${a_from_tag}::name]] != -1 } {
		    lappend checking_from_tag_list $a_from_tag
		}
	    }
	}
	# $tagdata(hilight-link-recursively)に入っている
	# fromtoのタグのみを checking_from_tag_listに入れる

	set next_to_tag_list [list]
	foreach a_fromto_tag $checking_from_tag_list {
	    if { ([lsearch -exact $done_list $a_fromto_tag]) != -1 } {
		continue
	    }
	    foreach a_to_tag $current_to_tag_list {
		if { [set ${a_fromto_tag}::id] == [set ${a_to_tag}::id] } {
		    continue
		}
		if { [set ${a_fromto_tag}::from] == [set ${a_to_tag}::from] \
			 && [set ${a_fromto_tag}::to] == [set ${a_to_tag}::to] } {
# 		    puts [${a_fromto_tag}::print]
		    # 対象となっている fromto_tagのうち，
		    # 今回ハイライトされている a_to_tagと同じ範囲に
		    # ある，fromto_tagについて
		    # hilight_recursivelyを呼ぶ
		    set done_list [hilight_recursively $a_fromto_tag 1 $done_list]
		}
	    }
	}
    }


    # ------------------------------
    # hilight_recursively($current_tag, $done_list)
    #   $current_tagから再帰的にハイラトさせる
    #   $hilight_flagに従ってハイライトする色を決める
    #   $done_listに入っているタグはハイライトさせない
    # ------------------------------
    public hilight_recursively {current_tag hilight_flag done_list} {
	variable from_tag_list
	variable to_tag_list
	variable rec_hilight_tag_list
	global tagdata

# 	puts "c: "
# 	puts ${current_tag}
# 	puts "d:"
# 	puts ${done_list}
# 	puts ""

	# ----------
	# すでにタグをハイライトしていたら，ここで終わる
	if { ([lsearch -exact $done_list $current_tag]) != -1 } {
	    return $done_list
	}

	# ----------
	# 自分をハイライトする
	switch $hilight_flag {
	    0 {
		# current_tagをハイライトする
		${current_tag}::annotate current-tag
		ScreenCommand tag configure current-tag -foreground $tagdata(link-from-color) -borderwidth 2 -underline true -background $tagdata(link-from-background-color)
		ScreenCommand tag raise current-tag
	    }
	    1 {
		# current_tagの隣り
		set fg $tagdata(hilight-link-list-neighbor-fg)
		set bg $tagdata(hilight-link-list-neighbor-bg)
		${current_tag}::annotate neighbor-tag
		ScreenCommand tag configure neighbor-tag -foreground $tagdata(hilight-link-list-neighbor-fg) -borderwidth 2 -underline true -background $tagdata(hilight-link-list-neighbor-bg)
		ScreenCommand tag raise neighbor-tag
	    }
	    default {
		# current_tagから 2つ以上離れているタグ
		set fg $tagdata(hilight-link-list-fg)
		set bg $tagdata(hilight-link-list-bg)
		${current_tag}::annotate linked-tag
		ScreenCommand tag configure linked-tag -foreground $tagdata(hilight-link-list-fg) -borderwidth 2 -underline true -background $tagdata(hilight-link-list-bg)
		ScreenCommand tag raise linked-tag
	    }
	}

	lappend done_list $current_tag
	set hilight_flag [expr $hilight_flag + 1]

	# ----------
	set ok 0
	# 対象のタグから再帰的に繰り返すかチェック
	# hilight-current-recursively ||
	# hilight-link-recursively
	# && link-from-list && link-tag-list ← これははずす2005-8-21(Sun)
	if { ([lsearch -exact $tagdata(hilight-link-recursively) [set ${current_tag}::name]] != -1) || ([lsearch -exact $tagdata(hilight-current-recursively) [set ${current_tag}::name]] != -1)} {
# 	    if { ([lsearch -exact $tagdata(link-from-list) [set ${current_tag}::name]] != -1) && ([lsearch -exact $tagdata(link-tag-list) [set ${current_tag}::name]] != -1) } {
	    set ok 1
# 	    }
	}
	if { $ok == 0 } {
	    return $done_list
	}


	# ----------
	# 再帰的に呼ぶ
	set id [${current_tag}::get_atrb id]
	set ln [${current_tag}::get_atrb ln]

	foreach a_checking $rec_hilight_tag_list {
	    # 同じものならば何もしない
	    if {[${a_checking}::get_atrb id] == $id} {
		continue
	    }
	    # すでにハイライトしていれば何もしない
	    if {[lsearch -exact $done_list $a_checking] != -1} {
		continue
	    }
	    # 係り元のハイライト
	    if {[${a_checking}::get_atrb id] == $ln} {
		# directedでないときだけ係り元にも伸ばす
		# directedのときは伸ばさない．
		if {[lsearch -exact $tagdata(hilight-directed-link-list) [set ${current_tag}::name]] == -1} {

		    # 係り元に伸ばすときには，hilight-link-list-neighborでは
		    # なく，link-listでハイライトするため
		    set done_list [hilight_recursively $a_checking [expr $hilight_flag + 1] $done_list]
		}
		continue
	    }
	    # 係り先のハイライト
	    if {[${a_checking}::get_atrb ln] == $id} {
		set done_list [hilight_recursively $a_checking $hilight_flag $done_list]
		continue
	    }
	    # 同じ場所にあるタグのハイライト
	    if { [set ${current_tag}::from] == [set ${a_checking}::from] \
		     && [set ${current_tag}::to] == [set ${a_checking}::to] } {
		set done_list [hilight_recursively $a_checking [expr $hilight_flag - 1] $done_list]

		continue
	    }
	}
#  	puts "\nr: "
#  	puts $done_list
	return $done_list

    }


# ------------------------------
# set_same_id_tags ${current_tag}
# from_tag_listの中で 引数で与えられたタグと同じ idのタグをハイライトする
# 一時的なものの予定なので，タグは set_from_tags ${to_tag_list}と同じ
# ものを使っている．
# ------------------------------
    public set_same_id_tags {current_tag} {
	variable from_tag_list
	global tagdata

	set cid [${current_tag}::get_atrb id]
	if {[string match $cid ""]} {
	    return 1
	}

	set ok 0
	foreach tag_id $from_tag_list {
	    set a_from_tag [[this]::id2tag $tag_id]
	    set aid [${a_from_tag}::get_atrb id]
	    if {![string match $cid ""] && [string match $cid $aid]} {
		${a_from_tag}::annotate refered-from-tag
		set ok 1
	    }
	}
	if { $ok == 1 } {
	    ScreenCommand tag configure refered-from-tag -foreground $tagdata(hilight-link-list-neighbor-fg) -borderwidth 2 -underline true -background $tagdata(hilight-link-list-neighbor-bg)
	    ScreenCommand tag raise refered-from-tag
	}
    }

# ------------------------------
#     set_attribute --> 1
#  SetDataに呼ばれ，属性の値をセットする
# ------------------------------
    public set_attribute {} {
	variable attribute
	global data

	foreach atrb $data(atrb-tf-list) {
	    set data(atrb-${atrb}) $attribute($atrb)
	}
	foreach atrb $data(atrb-text-list) {
	    set data(atrb-${atrb}) $attribute($atrb)
	}

	return 1
    }


# ------------------------------
#     display_tagcomment --> 1
#  SetDataに呼ばれ，タグコメントの値を表示する
# ------------------------------
    public display_tagcomment {} {
	variable current_id
	global data w

 	set current_tag [[this]::id2tag $current_id]

	if {![string match $current_tag NULL]} {
	    set data(tagcomment) [${current_tag}::get_atrb comment]
	}

	$w(tagcomment).entry config -background gray85
	
	# 色は gray85にする
	# コメントを入れたときにエンターでタグがセットされ，背景に色をつける

	return 1
    }


# ------------------------------
#     set_tagcomment --> 1
#  タグコメントの値をセットする
# ------------------------------
    public set_tagcomment {} {
	variable current_id
	global data w

 	set current_tag [[this]::id2tag $current_id]
	regsub -all ";" $data(tagcomment) "," new_comment
	${current_tag}::set_atrb comment ${new_comment}
	$w(tagcomment).entry config -background gray95
	
	return 1
    }


# ------------------------------
# add_attribute atrb value --> 1
# recordの属性を付与する
# ------------------------------
    public add_attribute {args} {
	variable attribute

	set atrb [lindex $args 0]
	set value [lindex $args 1]

	set attribute($atrb) $value

	return 1
    }


# ------------------------------
# next_link_from_tag --> 1
# デフォルトでは TABにバインドされている
# current_idを次に移動する
# ------------------------------
    public next_link_from_tag {} {
	variable max_tag_id
	variable current_id
	variable from_tag_list

	# id属性を持っているタグの中から，current_idを選ぶ
	set current_index [lsearch -exact $from_tag_list $current_id]
	if {$current_index == [expr [llength $from_tag_list] - 1]} {
	    set current_id [lindex $from_tag_list 0]
	} else {
	    set current_id [lindex $from_tag_list [expr $current_index + 1]]
	}

# 	puts $current_id
	return 1
    }


# ------------------------------
# previous_link_from_tag --> 1
# デフォルトでは Shift-TABにバインドされている
# current_idを前に移動する
# ------------------------------
    public previous_link_from_tag {} {
	variable max_tag_id
	variable current_id
	variable from_tag_list

	# id属性を持っているタグの中から，current_idを選ぶ
	set current_index [lsearch -exact $from_tag_list $current_id]
	if {$current_index == 0} {
	    set current_id [lindex $from_tag_list end]
	} else {
	    set current_id [lindex $from_tag_list [expr $current_index - 1]]
	}

# 	puts $current_id
	return 1
    }



# ------------------------------
# id2tag id --> tag / NULL
# idとして $idを持つ tagを返す
# idに対応するタグがない場合は NULLを返す
# ------------------------------
    private id2tag {id} {
	variable tags
	variable max_tag_id

	if [info exist tags($id)] {
	    return $tags($id)
	} else {
	    # 見付からなかったら，NULLを返す
	    return "NULL"
	}
    }


# ------------------------------
#     change_attribute --> 1
# 属性の値を変更する
# ------------------------------
    public  change_attribute {atrb value} {
	variable attribute
	set attribute($atrb) $value
	return 1
    }


# ------------------------------
# get_attribute atrb --> value / 0
# 属性の値を返す
# ------------------------------
    public get_attribute {atrb} {
	variable attribute

	if [info exist attribute($atrb)] {
	    return $attribute($atrb)
	} else {
	    return 0
	}
    }


# ------------------------------
#     return contents --> contents
# ------------------------------
    public contents {} {
	variable contents
	return $contents
    }

# ------------------------------
#     set_contents contents --> 1
# ------------------------------
    public set_contents {args} {
	variable contents
	set contents [lindex $args 0]
	return 1
    }

# ------------------------------
#     set_lastid lastid --> 1
# ------------------------------
    public set_lastid {args} {
	variable newtag_id
	set newtag_id [lindex $args 0]
	return 1
    }

# ------------------------------
#     append_tag tag mode --> 0:fail / 1:success
#     mode: tagging / read(from a file)
# ------------------------------
    public append_tag {args} {
	variable tags
	variable max_tag_id
	variable current_id
	variable aid2id
	variable newtag_id
	variable from_tag_list
	variable to_tag_list
	variable constant_tag_list
	variable link_reserved_list
	variable rec_hilight_tag_list
	global tagdata

	set new_tag [lindex $args 0]
	set mode [lindex $args 1]


	# id属性を持っていない場合，id属性を付与する．
	if [string match [${new_tag}::get_atrb id] ""] {
	    ${new_tag}::set_atrb id [format "newid%04d" $newtag_id]
	    incr newtag_id
	}

	# aid2idに登録する
	set aid [${new_tag}::get_atrb id]
	set aid2id($aid) [${new_tag}::id]


	if { ([lsearch -exact $tagdata(hilight-link-recursively) [set ${new_tag}::name]] != -1) || ([lsearch -exact $tagdata(hilight-current-recursively) [set ${new_tag}::name]] != -1)} {
	    lappend rec_hilight_tag_list $new_tag
	}
	

	# 追加する tagの種類毎の処理
	switch [set ${new_tag}::tag_type] {
	    fromto {
		# ---------- to ----------
		# to_tag_listにIDを追加
		lappend to_tag_list [${new_tag}::id]

		# リンク先の場合，リンク元に自分の IDを登録する．
		set link_to [${new_tag}::get_atrb ln]
		# link_tagで
		if [string match $link_to ""] {
		    # リンク先を持っていない場合，
		    if [string match $mode "tagging"] {
			# タギング時
			set current_tag [[this]::id2tag $current_id]
			if {![string match $current_tag NULL]} {
			    ${new_tag}::set_atrb ln [${current_tag}::get_atrb id]
			    # 変更のあるタグを Undoのために保存する．
			    set_tag_undo ${current_tag}
			    # 現在の current_tagに，new_tagの IDを追加する．
			    ${current_tag}::add_linked [set ${new_tag}::id]
			} else {
			    # 何もしない
			}
		    } else {
			# ファイルからの読み込み時
			# 何もしない
		    }
		} else {
		    # リンク先を持っていた場合，
		    # リンクさきのタグに new_tagの IDを追加する
		    if [info exist aid2id($link_to)] {
			# リンク先がすでに登録されていれば，
			set link_from_tag [[this]::id2tag $aid2id($link_to)]
			if {![string match $link_from_tag NULL]} {
			    # 変更のあるタグを Undoのために保存する．
 			    set_tag_undo ${link_from_tag}
			    # そのタグが存在すれば linked_listに追加する
			    ${link_from_tag}::add_linked [set ${new_tag}::id]
			} else {
			    # そのタグが存在しなければ，メッセージを出す
			    Message "Tag($link_to) is not exist."
			    # todo ${new_tag}::remove_atrb ln をするべきかも
			}
		    } else {
			# リンク先がまだ登録されていなければ，
			lappend link_reserved_list [list $link_to [set ${new_tag}::id]]
		    }
		}



		# ---------- from ----------
		# タグが現在選択されている場合，from_tag_listにIDを追加
		if {[lsearch -exact $tagdata(current-from-list) [set ${new_tag}::name]] != -1} {
		    lappend from_tag_list [${new_tag}::id]

		    # 新しく付与した from_tagを current tagとする．
		    set current_id [${new_tag}::id]
		}

		# 自分が，link-fromの登録がまだだった link-toに対する link-fromだった場合
		# linked_listに追加する．
		foreach a_pair $link_reserved_list {
		    if [string match [lindex $a_pair 0] $aid] {
			${new_tag}::add_linked [lindex $a_pair 1]
		    }
		}



	    }

	    from {
		# タグが現在選択されている場合，from_tag_listにIDを追加
		if {[lsearch -exact $tagdata(current-from-list) [set ${new_tag}::name]] != -1} {
		    lappend from_tag_list [${new_tag}::id]

		    # 新しく付与した from_tagを current tagとする．
		    set current_id [${new_tag}::id]
		}

		# 自分が，link-fromの登録がまだだった link-toに対する link-fromだった場合
		# linked_listに追加する．
		foreach a_pair $link_reserved_list {
		    if [string match [lindex $a_pair 0] $aid] {
			${new_tag}::add_linked [lindex $a_pair 1]
		    }
		}
	    }

	    to {
		# to_tag_listにIDを追加
		lappend to_tag_list [${new_tag}::id]

		# リンク先の場合，リンク元に自分の IDを登録する．
		set link_to [${new_tag}::get_atrb ln]
		# link_tagで
		if [string match $link_to ""] {
		    # リンク先を持っていない場合，
		    # 現在の current_tagを指す
		    set current_tag [[this]::id2tag $current_id]
		    if {![string match $current_tag NULL]} {
			${new_tag}::set_atrb ln [${current_tag}::get_atrb id]
			# 変更のあるタグを Undoのために保存する．
 			set_tag_undo ${current_tag}
			# 現在の current_tagに，new_tagの IDを追加する．
			${current_tag}::add_linked [set ${new_tag}::id]
		    } else {
			# todo
			# リンク元が無い場合は追加しない
			# ただこの場合も to_tag_listや aid2id(),newtag_id
			# は変更されている．
			# これらの値を戻した方がよいのかもしれない．
			return 0
		    }
		} else {
		    # リンク先を持っていた場合，
		    # リンクさきのタグに new_tagの IDを追加する
		    if [info exist aid2id($link_to)] {
			# リンク先がすでに登録されていれば，
			set link_from_tag [[this]::id2tag $aid2id($link_to)]
			if {![string match $link_from_tag NULL]} {
			    # 変更のあるタグを Undoのために保存する．
 			    set_tag_undo ${link_from_tag}
			    # そのタグが存在すれば linked_listに追加する
			    ${link_from_tag}::add_linked [set ${new_tag}::id]
			} else {
			    # そのタグが存在しなければ，メッセージを出す
			    Message "Tag($link_to) is not exist."
			    # todo ${new_tag}::remove_atrb ln をするべきかも
			}
		    } else {
			# リンク先がまだ登録されていなければ，
			lappend link_reserved_list [list $link_to [set ${new_tag}::id]]
		    }
		}
	    }

	    constant {
		if [${new_tag}::is_constant] {
		    # constant_tag_listにIDを追加
		    lappend constant_tag_list [${new_tag}::id]
		}
	    }
	}



	# タグを追加する．
	set tags([${new_tag}::id]) ${new_tag}
	incr max_tag_id

	return 1
    }


# ------------------------------
#     next_id --> max_tag_id
# max_tag_idを返す．
# ------------------------------
    public next_id {} {
	variable max_tag_id
	set return_value ${max_tag_id}
	return ${return_value}
    }


# ------------------------------
#     get_a_tags --> tag
# ------------------------------
    public get_a_tag {index} {
	variable tags
	return $tags($index)
    }

# ------------------------------
#     id --> id
# ------------------------------
    public id {} {
	variable id
	return $id
    }


    # ------------------------------
    # current_selected_tagによって，クリックしたときに同じタグを複数回
    # ハイライトしないようにしているが，NextNewData, PreviousNewDataで移動
    # した場合は，ハイライトされているタグが移動したので，current_selected_tagを
    # リセットする
    # ------------------------------
    public reset_current_selected_tag {} {
	variable current_selected_tag
	set current_selected_tag [list]
    }


# ------------------------------
# set_current_id id --> 1
# current_idに値をセットする
# ------------------------------
    public set_current_id {select_id} {
	variable current_id
	variable current_selected_tag

	# todo
	# is_fromだけでなく，複数の is_fromを意識する必要があるかも．
	# この述語では必要ないと思う．

	set select_tag [[this]::id2tag $select_id]

	if [string match $select_tag NULL] {
	    set current_id -1
	    return 1
	}


	if {[llength $current_selected_tag] == 3} {
	    set name [lindex $current_selected_tag 0]
	    set from [lindex $current_selected_tag 1]
	    set to [lindex $current_selected_tag 2]
	    if {[${select_tag}::get_atrb name] == $name &&
		[set ${select_tag}::from] == $from &&
		[set ${select_tag}::to] == $to} {
		return 0
	    }
	}

	set current_selected_tag \
	    [list [${select_tag}::get_atrb name] \
		 [set ${select_tag}::from] \
		 [set ${select_tag}::to]]

	if {[${select_tag}::is_from]} {
	    set current_id $select_id
	}

	return 1
    }


# ------------------------------
#     remove_tag {[sel-from sel-to] already_removed_tag_list}
# カーソル上のタグ，あるいは範囲指定されたタグの一部を削除する
#
# 再帰的にタグ削除するときには，select_rangeに範囲ではなく，
# タグを指定する．それは select_rangeの要素の数で判断できる．
# ------------------------------
    public remove_tag {select_range already_removed_tag_list} {
	global tagdata
	variable tags
	variable current_id
	variable max_tag_id

	set removed_aid_list [list]
	set removed_tag [list]

	if {[llength $select_range] == 1} {
	    # 指定されたタグの削除を行なう
	    set tag [lindex $select_range 0]
	    lappend removed_aid_list [${tag}::get_atrb id]
	    lappend removed_tag ${tag}

	} else {
	    # 選択された範囲またはカーソルの位置からタグを削除する
	    set sel_start [lindex $select_range 0]
	    set sel_end [lindex $select_range 1]
	    set current_tag [[this]::id2tag $current_id]

	    if { [string length $sel_start] != 0 } {
		# スクリーン上で選択された領域のタグをはがず
		for {set i 0} {$i < $max_tag_id} {incr i} {
		    set tag $tags($i)
		    if {$tag == "NULL"} continue
		    if {[${tag}::status] && ![${tag}::read_only]} {
			# リンク先のタグでない または リンク先が current_aidの時 削除する対象になる
			if [string match $current_tag NULL] {
			    set current_aid "NULL"
			} else {
			    set current_aid [${current_tag}::get_atrb id]
			}
			if {![${tag}::in_link_tag_list] || [${tag}::is_fromto] ||
			    [string match $current_aid [${tag}::get_atrb ln]]}  {
			    if [${tag}::remove_range $sel_start $sel_end] {
				# --- 削除ルーチン --- #

				# 削除リストに追加する．
				lappend removed_tag ${tag}

				# 消されたタグが id属性を持っていればリストに追加する
				set aid [${tag}::get_atrb id]
				if ![string match $aid ""] {
				    lappend removed_aid_list $aid
				}
			    }
			}
		    }
		}

	    } else {
		# スクリーン上でカーソルのある範囲にあるタグをはずす
		set cursor [GetScreenCursor]
		for {set i 0} {$i < $max_tag_id} {incr i} {
		    set tag $tags($i)
		    if {$tag == "NULL"} continue
		    if {[${tag}::status] && ![${tag}::read_only]} {
			# リンク先のタグでない または リンク先が current_aidの時 削除する対象になる
			if [string match $current_tag NULL] {
			    set current_aid "NULL"
			} else {
			    set current_aid [${current_tag}::get_atrb id]
			}
			if {![${tag}::in_link_tag_list] || [${tag}::is_fromto] ||
			    [string match $current_aid [${tag}::get_atrb ln]]}  {
			    if [${tag}::on_cursor $cursor] {
				# --- 削除ルーチン --- #

				# 削除リストに追加する．
				lappend removed_tag ${tag}

				# 消されたタグが id属性を持っていればリストに追加する
				set aid [${tag}::get_atrb id]
				if ![string match $aid ""] {
				    lappend removed_aid_list $aid
				}
			    }
			}
		    }
		}
	    }
	}


	# 削除されたタグの aidを指しているノードがあった場合，警告を出す
	# なかった場合，removed_tagに登録されているタグを消す

	# todo removed_tag drivenでやる．

	set orphan [list]
	for {set i 0} {$i < $max_tag_id} {incr i} {
	    set tag $tags($i)
	    if {$tag == "NULL"} continue
	    if { [lsearch $removed_aid_list [${tag}::get_atrb ln]] != -1} {
 		if { [lsearch $already_removed_tag_list $tag] == -1} {
		    lappend orphan ${tag}
 		}
	    }
	}

# 	puts "removed_tag"
# 	foreach i $removed_tag {
# 	    ${i}::print
# 	}
# 	puts "orphan"
# 	foreach i $orphan {
# 	    ${i}::print
# 	}


	if {[llength $orphan] > 0} {
	    foreach tag $orphan {
		${tag}::set_warnning
	    }
	    ScreenCommand tag configure warnning -foreground $tagdata(warnning-fg-color) -background $tagdata(warnning-bg-color)
	    ScreenCommand tag raise warnning
# 	    set rem [YN_Message "There are tags which depend on the removed tag."]
	    set rem [YN_Message "このタグにリンクされているタグがありますが削除しますか？"]
	    ScreenCommand tag delete warnning
	    if [string match $rem "yes"] {

		# みなしごとなるタグを削除
		foreach rtag $removed_tag {
		    lappend already_removed_tag_list $rtag
		}
		foreach tag $orphan {
		    # $removed_tagに入っていたら $removed_tagから削除
		    if {[set del_index [lsearch $removed_tag $tag]] != -1} {
			set removed_tag [lreplace $removed_tag ${del_index} ${del_index}]
		    }

		    set rem_result [[this]::remove_tag [list ${tag}] $already_removed_tag_list]
		    # 途中でキャンセルがあった場合は，中断して 0を返す
		    if {$rem_result == 0} {
			return 0
		    }
		}
		# 削除すべきタグを削除
		foreach tag $removed_tag {
		    [this]::remove_tag_body ${tag}
		}
	    } else {
		return 0
	    }
	} else {
	    # 削除すべきタグを削除
	    foreach tag $removed_tag {
		[this]::remove_tag_body ${tag}
	    }
	}
	return 1
    }


# ------------------------------
# remove_tag_body
# 実際にタグを消す．
# ------------------------------
    public remove_tag_body {tag} {
	variable tags
	variable aid2id
	variable from_tag_list
	variable to_tag_list
	variable constant_tag_list
	variable rec_hilight_tag_list

	# 変更のあるタグを Undoのために保存する．
	set_tag_undo ${tag}

	set id [${tag}::id]
	set tags($id) "NULL"

	# $rec_hilight_tag_listに入っていたらそこから消す
	set tmp_rec_hilight_tag_list [list]
	foreach atag $rec_hilight_tag_list {
	    if {[set ${tag}::id] != [set ${atag}::id]} {
		lappend tmp_rec_hilight_tag_list $atag
	    }
	}
	set rec_hilight_tag_list $tmp_rec_hilight_tag_list

	switch [set ${tag}::tag_type] {
	    fromto {
		# from_tag_listから tagの IDを消す
		set index [lsearch $from_tag_list $id]
		set from_tag_list [lreplace $from_tag_list $index $index]
		# to_tag_listから tagの IDを消す
		set index [lsearch $to_tag_list $id]
		set to_tag_list [lreplace $to_tag_list $index $index]
	    }
	    from {
		# from_tag_listから tagの IDを消す
		set index [lsearch $from_tag_list $id]
		set from_tag_list [lreplace $from_tag_list $index $index]

	    }
	    to {
		# to_tag_listから tagの IDを消す
		set index [lsearch $to_tag_list $id]
		set to_tag_list [lreplace $to_tag_list $index $index]
	    }
	    constant {
		# constant_tag_listから tagの IDを消す
		set index [lsearch $constant_tag_list $id]
		set constant_tag_list [lreplace $constant_tag_list $index $index]
	    }
	}
    }



# ------------------------------
#     print [file-stream]
# streamが指定されていれば，その streamに出力する
# ------------------------------
    public print {args} {
	variable id
	variable tags
	variable contents
	variable attribute
	variable newtag_id
	variable max_tag_id
	global data

	set stream [lindex $args 0]
	if [string match $stream ""] {
	    set stream stdout
	}

	puts $stream "<text id=$id>"

	puts $stream "<contents>"
	puts -nonewline $stream $contents
	puts $stream "</contents>"

	puts $stream "<attribute>"
	foreach atrb $data(atrb-tf-list) {
	    puts $stream [format "%s\t%s" ${atrb} $attribute($atrb)]
	}
	foreach atrb $data(atrb-text-list) {
	    puts $stream [format "%s\t%s" ${atrb} $attribute($atrb)]
	}
	puts $stream "</attribute>"

	puts $stream "<lastid>"
	puts $stream $newtag_id
	puts $stream "</lastid>"

	puts $stream "<tags>"
	for {set i 0} {$i < $max_tag_id} {incr i} {
	    set tag $tags($i)
	    if {$tag == "NULL"} continue
	    ${tag}::print $stream
	}
	puts $stream "</tags>"
	puts $stream "</text>"
    }


# ------------------------------
#     export [file-stream]
# streamが指定されていれば，その streamに出力する
# ------------------------------
    public export {args} {
	variable id
	variable tags
	variable contents
	variable attribute
	variable newtag_id
	variable max_tag_id
	global data screen1

	set stream [lindex $args 0]
	if [string match $stream ""] {
	    set stream stdout
	}

	puts $stream "<text id=$id>"
	puts $stream "<contents>"
	# ---------- write tag ----------
# 	set tag_pos [list]
	for {set i 0} {$i < $max_tag_id} {incr i} {
	    set a_tag $tags($i)
	    if { $a_tag != "NULL" } {
		${a_tag}::add_mark $i
	    }
	}

	# 開始タグ
	set me [$screen1 mark next 1.0]
	while {$me != ""} {
	    set new_me [$screen1 mark next $me]
	    if {[regexp {^pre::(.+)::([0-9]+)$} $me dummy tagname num]} {
		set tag [format "<%s>" $tagname]
		$screen1 insert $me $tag
		$screen1 mark unset $me
	    }
	    set me $new_me
	}

	# 終了タグ
	set me [$screen1 mark previous end]
	while {$me != ""} {
	    set new_me [$screen1 mark previous $me]
	    if {[regexp {^post::(.+)::([0-9]+)$} $me dummy tagname num]} {
		set tag [format "</%s>" $tagname]
		$screen1 insert $me $tag
		$screen1 mark unset $me
	    }
	    set me $new_me
	}


	# -------------------------------
	puts -nonewline $stream [$screen1 get 1.0 end]
	puts $stream "</contents>"

	puts $stream "<attribute>"
	foreach atrb $data(atrb-tf-list) {
	    puts $stream [format "%s\t%s" ${atrb} $attribute($atrb)]
	}
	foreach atrb $data(atrb-text-list) {
	    puts $stream [format "%s\t%s" ${atrb} $attribute($atrb)]
	}
	puts $stream "</attribute>"
	puts $stream "</text>"
    }


# ------------------------------
# show_current_tag [file-stream]
# current_tagの情報を出力する
# current_tagに対してリンクを持っているタグも出力する
# streamが指定されていれば，その streamに出力する
# ------------------------------
    public show_current_tag {args} {
	variable tags
	variable current_id
	variable aid2id
	variable max_tag_id
	variable to_tag_list

	set stream [lindex $args 0]
	if [string match $stream ""] {
	    set stream stdout
	}

	if {$current_id == -1} {
	    puts $stream "unselected"
	    return
	}

 	set current_tag [[this]::id2tag $current_id]
	puts $stream "<current_tagset>"
	puts $stream "<from_tag>"
	${current_tag}::show
	puts $stream "</from_tag>"

	puts $stream "<to_tag>"
	set current_tagid [${current_tag}::get_atrb id]

	foreach i $to_tag_list {
	    set tag $tags($i)
	    if [string match $current_tagid [${tag}::get_atrb ln]] {
		${tag}::show
	    }
	}

	puts $stream "</to_tag>"
	puts $stream "</current_tagset>"

    }



# ------------------------------
# show_tag tag_id [file-stream]
# 第一引数に指定された tagの情報を出力する
# そのtagに対してリンクを持っているタグも出力する
# streamが指定されていれば，その streamに出力する
# ------------------------------
    public show_tag {args} {
	variable tags
	variable aid2id
	variable max_tag_id

	set tag [lindex $args 0]
	set stream [lindex $args 1]
	if [string match $stream ""] {
	    set stream stdout
	}

	${tag}::show

	if [${tag}::is_from] {

	    # todo この述語はデバッグ用で使われていないから，
	    # がんばって修正する必要はないかも．

	    for {set i 0} {$i < $max_tag_id} {incr i} {
		set eachtag $tags($i)
		if {$eachtag == "NULL"} continue
		if [${eachtag}::in_link_tag_list] {
		    if {[string match [${tag}::get_atrb id] [${eachtag}::get_atrb ln]]} {
			puts -nonewline $stream "  >"
			${eachtag}::show $stream
		    }
		}
	    }
	}
    }


# ------------------------------
# 編集されたテキストを元に現在のタグの位置情報を更新する
# また contentsも現在のものに更新する
# ------------------------------
    public reset_text {} {
	variable tags
	variable contents
	variable from_tag_list
	variable to_tag_list
	variable constant_tag_list

	foreach tag_id [concat ${from_tag_list} ${to_tag_list} ${constant_tag_list}] {
	    $tags(${tag_id})::reset_position
	}

	set_contents [ScreenCommand get 1.0 end]
    }


}

# ================================================== #
#  tag
# ================================================== #
object tag {
    # string / タグの名前(種類)
    property name
    # integer / タグの ID
    property id
    # list of string / 持っている属性名のリスト
    property atrb_list
    # array / 属性を配列で持つ
    property atrb
    # integer.integer / 位置
    property from
    # integer.integer / 位置
    property to
    # string (from, to, constant) / タグの種類
    property tag_type
    # list of id / 自分自身を linkしているタグの ID
    property linked_list
    # 0/1 / hilight candかどうか
    property is_hilight_cand

# ------------------------------
#     construct name begin end atrb_list --> 0/object
#     success: object, fail: 0
# ------------------------------
    public construct {args} {
	global tagdata
	variable name
	variable id
	variable from
	variable to
	variable atrb_list
	variable atrb
	variable tag_type
	variable linked_list
	variable is_hilight_cand
	
	set name [lindex $args 0]
	set id [lindex $args 1]
	set from [lindex $args 2]
	set to [lindex $args 3]
	set tmp_atrb_list [lindex $args 4]
	set tag_type "constant"
	set linked_list [list]
	set is_hilight_cand 0
	if {[regexp {NULL} $from] || [regexp {NULL} $to]} {
	    return 0
	}

	# tag_typeをセットする
	if {[lsearch $tagdata(link-from-list) $name] != -1} {
	    set tag_type "from"
	} 
	if {[lsearch $tagdata(link-tag-list) $name] != -1} {
	    set tag_type "to"
	}
	if {[lsearch $tagdata(link-tag-list) $name] != -1 && [lsearch $tagdata(link-from-list) $name] != -1} {
	    set tag_type "fromto"
	}

	# is_hilight_candをセットする
	if {[lsearch $tagdata(cand-hilight-list) $name] != -1} {
	    set is_hilight_cand 1
	}	

	set atrb_list [list]

 	foreach i [split [string trimright $tmp_atrb_list ";"] ";"] {
	    regexp {^(.*)=(.*)$} $i dummy atribute value
	    set atrb($atribute) $value
	    lappend atrb_list $atribute
	}

	return [this]
    }



# ------------------------------
# copy tag -> 1
# 引数に与えられた tagの情報をコピーする
# ------------------------------
    public copy {source_tag} {
	variable name
	variable id
	variable from
	variable to
	variable atrb_list
	variable atrb
	variable tag_type
	variable linked_list
	variable is_hilight_cand

	set name [set ${source_tag}::name]
	set id [set ${source_tag}::id]
	set from [set ${source_tag}::from]
	set to [set ${source_tag}::to]
	set atrb_list [set ${source_tag}::atrb_list]
	set tag_type [set ${source_tag}::tag_type]
	set linked_list [set ${source_tag}::linked_list]
	set is_hilight_cand [set ${source_tag}::is_hilight_cand]
	
	array set atrb [array get ${source_tag}::atrb]

	return 1
    }


# ------------------------------
# add_linked tag_id
# 引数に与えられた "tagの ID"を linked_listに追加する．
# ------------------------------
    public add_linked {args} {
	variable linked_list

	set id [lindex $args 0]
	lappend linked_list $id
    }


# ------------------------------
# delete_linked tag_id
# 引数に与えられた "tagの ID"を linked_listから削除する．
# ------------------------------
    public delete_linked {args} {
	variable linked_list

	set id [lindex $args 0]
	set index [lsearch $linked_list $id]
	# linkded_listの中に idが見付からなかった場合は indexは -1となるが
	# この場合 lreplaceでは何も起きない．
	set linked_list [lreplace $linked_list $index $index]
    }


# ------------------------------
#     is_same tag --> 0/1
#     タグの名前と領域と ln属性が同じなら 1を返す
# ------------------------------
    public is_same {args} {
	variable name
	variable from
	variable to
	variable atrb

	set tag [lindex $args 0]

	if { ![string match $from [set ${tag}::from]] } {
	    return 0
	}

	if { ![string match $to [set ${tag}::to]] } {
	    return 0
	}

	if { ![string match $name [set ${tag}::name]] } {
	    return 0
	}

	if { ![string match [[this]::get_atrb ln] [${tag}::get_atrb ln]] } {
	    return 0
	}

	return 1
    }


# ------------------------------
# warnning -> 1
# 警告を出す
# ------------------------------
    public set_warnning {} {
	variable from
	variable to
	global screen tagdata

	ScreenCommand tag add warnning $from $to
    }

# ------------------------------
# on_cursor cursor/index
# 0:タグがcursorの上にある，1:cursorの上にない
# ------------------------------
    public on_cursor {cursor_index} {
	variable from
	variable to
	
	set cursor [Position_val $cursor_index]
	set tf [Position_val $from]
	set tt [Position_val $to]

	if {$tf <= $cursor && $cursor <= $tt} {
	    return 1
	}
	return 0
    }


# ------------------------------
# remove_range
# 1: 消えてしまった，0:タグの範囲が変わらなかった or 範囲を修正した
# ------------------------------
    public remove_range {sel_from sel_to} {
	variable from
	variable to
	
	set sf [Position_val $sel_from]
	set st [Position_val $sel_to]
	set tf [Position_val $from]
	set tt [Position_val $to]

# 	tagと selが重なっていない
	if {$st < $tf || $tt < $sf} {
	    return 0
	}

# 	tagを selが覆っている
	if {$sf <= $tf && $tt <= $st} {
	    return 1
	}

# 	tagが一部重なっているときは，selの情報を変更する
# 	  tagの左の部分を選択している
	if {$sf <= $tf && $st <= $tt} {
	    set from $sel_to
	    return 0
	}

# 	  tagの右の部分を選択している
	if {$tf <= $sf && $tt <= $st} {
	    set to $sel_from
	    return 0
	}

	return 1
    }


# ------------------------------
#     add_sel --> 1
#     タグの領域を選択する
# ------------------------------
    public add_sel {} {
	variable from
	variable to

 	ScreenActiveCommand tag add sel $from $to
	return 1
    }


# ------------------------------
#     annotate --> 1
#     annotate tag_name --> 1
#     タグを付与する
# ------------------------------
    public annotate {args} {
	variable name
	variable id
	variable from
	variable to
	variable atrb
	variable is_hilight_cand
	global tagdata w

	# statusが0のときは付与しない．
	if ![[this]::status] {
	    return 0
	}

	# 引数が指定されていれば，第一引数で指定されてタグ名をふる
	if {[llength $args] == 0} {
	    set tagname $name
	} else {
	    set tagname [lindex $args 0]
	}

	# タグを出力
	ScreenCommand tag add $tagname $from $to

	# "tag-${id}"という名前でもタグを付ける
	# 位置がずれたときに，位置情報を新たにふり直すため
	ScreenCommand tag add tag-${id} $from $to

	# タグボタン中の付与したタグをハイライトする．
	if [[this]::is_from] {
	    
	    # マウスイベントにバインドする
	    set fromtag [format "%s-%s" $name $id]
	    ScreenCommand tag add $fromtag $from $to
	    ScreenCommand tag bind $fromtag <Button-1> "SelectNewData $id"
	    ScreenCommand tag bind $fromtag <Control-Button-1> "SetStatus \"\""

	    $tagdata(${name}-cb) config -background $tagdata(from-tag-color)
	}

	if [[this]::is_to] {
	    $tagdata(${name}-cb) config -background $tagdata(to-tag-color)

	}
	if [[this]::is_constant] {
	    $tagdata(${name}-cb) config -background $tagdata(marked-tag-color)
	}


	# tagdata(cand-hilight-list)のタグについて，対象としているタグが
	# current-from-tagに入っていたら，ハイライトする
	if $is_hilight_cand {
	    set hilight_flag 0
	    foreach a_from $tagdata(cand-hilight-${name}) {
		if {[lsearch $tagdata(current-from-list) $a_from] != -1} {
		    set hilight_flag 1
		}
	    }

	    if {$hilight_flag == 1} {
		set candtag [format "%s-%s" $name $id]
		ScreenCommand tag add $candtag $from $to
		ScreenCommand tag bind $candtag <Enter> \
 		    "ScreenCommand tag configure $candtag \
                       -borderwidth $tagdata(cand-hilight-width) \
                       -relief ridge;
                     ScreenCommand tag raise $candtag"
		ScreenCommand tag bind $candtag <Leave> \
		    "ScreenCommand tag configure $candtag \
                       -relief flat"
	    }
	}


	ScreenCommand tag raise $name
	return 1
    }


# ------------------------------
# reset_position
# テキストが編集されたときに，新しいタグの場所を付与し直す．
# ------------------------------
    public reset_position {} {
	variable id
	variable from
	variable to

	set tag_range [ScreenCommand tag ranges tag-${id}]
	if { [llength $tag_range] > 1 } {
	    set from [lindex $tag_range 0]
	    set to [lindex $tag_range 1]
	}
    }


# ------------------------------
#  id -> id
# idを返す
# ------------------------------
    public id {} {
	variable id
	return $id
    }


# ------------------------------
#    is_fromto --> 0/1
# link_from & link_toの時に 1を返す
# ------------------------------
    public is_fromto {} {
	variable tag_type

	if {$tag_type == "fromto"} {
	    return 1
	} else {
	    return 0
	}
    }


# ------------------------------
#    is_from --> 0/1
# link_fromの時に 1を返す
# ------------------------------
    public is_from {} {
	variable tag_type

	if {$tag_type == "from" || $tag_type == "fromto"} {
	    return 1
	} else {
	    return 0
	}
    }


# ------------------------------
#    is_to --> 0/1
# link_tag_listに入っている時に 1を返す
# ------------------------------
    public is_to {} {
        return [[this]::in_link_tag_list]
    }


# ------------------------------
# in_link_tag_list tag --> 0/1
# tagが link-tag-listに入っているときに 1を返す
# ------------------------------
    public in_link_tag_list {} {
	variable tag_type

	if {$tag_type == "to" || $tag_type == "fromto"} {
	    return 1
	} else {
	    return 0
	}
    }


# ------------------------------
# is_constant --> 0/1
# tagが，from-listにも link_tag_listにも入っていない時に 1を返す
# ------------------------------
    public is_constant {} {
	variable tag_type

	if {$tag_type == "constant"} {
	    return 1
	} else {
	    return 0
	}
    }


# ------------------------------
#     set_atrb atribute value --> 1
# 属性の追加を行なう
# ------------------------------
    private set_atrb {args} {
	variable atrb
	variable atrb_list

	set atribute [lindex $args 0]
	set value [lindex $args 1]
	set atrb($atribute) $value

	if {[lsearch -exact $atrb_list $atribute] == -1} {
	    lappend atrb_list $atribute
	}
	return 1
    }

# ------------------------------
#     get_atrb atribute --> value / ""
# ------------------------------
    private get_atrb {args} {
	variable atrb
	set atribute [lindex $args 0]
	if [info exist atrb($atribute)] {
	    return $atrb($atribute)
	} else {
	    return ""
	}
    }


# ------------------------------
#     remove_atrb atribute --> 0/1
# ------------------------------
    private remove_atrb {args} {
	variable atrb
	variable atrb_list

	set atribute [lindex $args 0]
	if [info exist atrb($atribute)] {
	    unset atrb($atribute)
	    set atrb_list [Lremove $atrb_list $atribute]
	    return 1
	} else {
	    return 0
	}
    }


# ------------------------------
# status --> 0/1
# return status
# グローバル変数を使っているので，よくない．
# ------------------------------
    public status {} {
	global tagdata
	variable name

	return $tagdata(${name}-status)
    }


# ------------------------------
# set_status 0/1 --> 1
# set status
# 結局グローバル変数を直接触ったので，このメソッドは使っていない．
# ------------------------------
    public set_status {new_status} {
	global tagdata
	variable name

	set $tagdata(${name}-status) ${new_status}
	return 1
    }


# ------------------------------
# read_only --> 0/1
# return read_only flag. If the flag is unset, return 0
# ------------------------------
    public read_only {} {
	global tagdata
	variable name

	if ![info exist tagdata(${name}-ro)] {
	    return 0
	}
	return $tagdata(${name}-ro)
    }

# ------------------------------
#     print [file-stream]
# streamが指定されていれば，その streamに出力する
# ------------------------------
    public print {args} {
	variable name
	variable id
	variable from
	variable to
	variable atrb_list
	variable atrb

	set stream [lindex $args 0]
	if [string match $stream ""] {
	    set stream stdout
	}

	puts -nonewline $stream [format "%s\tid:%s\t" $name $id ]
	puts -nonewline $stream "\[$from, $to\]\t"
	foreach each_atrb $atrb_list {
	    puts -nonewline $stream "$each_atrb=$atrb($each_atrb);"
	}
	puts $stream ""
    }


# ------------------------------
#     show [file-stream]
# streamが指定されていれば，その streamに出力する
# ------------------------------
    public show {args} {
	variable name
	variable id
	variable from
	variable to
	variable atrb_list
	variable atrb
	global screen1

	set stream [lindex $args 0]
	if [string match $stream ""] {
	    set stream stdout
	}

	puts -nonewline $stream [format "%s\t%s\tid:%s\t" [$screen1 get $from $to] $name $id ]
	puts -nonewline $stream "\[$from, $to\]\t"
	foreach each_atrb $atrb_list {
	    puts -nonewline $stream "$each_atrb=$atrb($each_atrb);"
	}
	puts $stream ""
    }


# ------------------------------
# from {}
# タグの開始位置を返す
# ------------------------------
    public from {} {
	variable from
	return $from
    }


    # ------------------------------
    # add_mark {num}
    # 現在表示されているテキストに，マークをセットする
    # ------------------------------
    public add_mark {num} {
 	variable name
# 	variable id
 	variable from
 	variable to
 	variable atrb_list
 	variable atrb
# 	variable tag_type
# 	variable linked_list
# 	variable is_hilight_cand
	global screen1

	# statusが0のときは markを付与しない．
	if ![[this]::status] {
	    return 0
	}

	set atrb_pair_list [list]
	foreach each_atrb $atrb_list {
	    lappend atrb_pair_list "$each_atrb=$atrb($each_atrb)"
	}
	set atrb_string [join $atrb_pair_list ";"]

	if {$atrb_string == ""} {
	    set pre [format "pre::%s::%i" $name $num]
	} else {
	    set pre [format "pre::%s %s::%i" $name $atrb_string $num]
	}
	set post [format "post::%s::%i" $name $num]


	$screen1 mark set $pre $from
 	$screen1 mark set $post $to
    }


}

# ====================================================================== #
### Make Tag ###
proc MakeTag {} {
    global w tagdata

    for {set tagset 1} {$tagset <= $tagdata(tag-list-num)} {incr tagset} {
	if {[llength $tagdata(tag-list${tagset})] == 0} {
	    break
	}

	set each_set $w(bottom).set${tagset}
	frame ${each_set}
	pack ${each_set} -side left -padx 5 -pady 5 -anchor n

# 	set header ${each_set}.header
# 	frame $header
# 	label $header.tag -width 15 -text "Tag"
# 	label $header.color -width 9 -text "Color"
# 	label $header.bind -width 3 -text "Set"
# 	pack $header.tag -side left
# 	pack $header.color -side left -expand no -padx 10
# 	pack $header.bind -side left -expand no -padx 10
# 	pack $header -side top -expand no -fill x
	
	foreach each_tag $tagdata(tag-list${tagset}) {
	    set box_name ${each_tag}-box
	    set $box_name ${each_set}.$each_tag-box
	    MakeTagElem [set $box_name] $each_tag
	    pack [set $box_name] -side top -expand no -fill x
	}
    }
}


### Make labeled menu ###
proc MakeTagElem { frame_name name } {
    global w tagdata sysconf

    set label $name
    set key tagdata(${name}-bind)
    set val tagdata(${name}-status)

    frame $frame_name  -borderwidth 1 -relief ridge -background gray85

    frame $frame_name.name
    label $frame_name.name.label -font $w(font) -text $label
    checkbutton $frame_name.name.cb -font $w(font) -text $label -variable $val \
	-anchor w -command "ActivateTag $name"

    # annotateでタグを付与するときに，チェックボタンをハイライトするため，
    # global variableに入れておく．
    set tagdata(${name}-cb) $frame_name.name.cb

    menubutton $frame_name.menu -font $w(font) -text $tagdata(${name}-fcolor) \
	    -fg $tagdata(${name}-fcolor) -bg $tagdata(${name}-bcolor) \
	    -menu $frame_name.menu.m -relief raised -width 8
    menu $frame_name.menu.m -tearoff no
    foreach color $tagdata(color-list) {
	$frame_name.menu.m add command -label $color -command \
	  "SetColor $name ${frame_name}.menu $color"
    }	

    if {[string length [set $key]] > 0} {
 	regsub {ontrol} [set $key] "" short_name
	if {$sysconf(tagbutton) == 0} {
	    button $frame_name.entry -text ${short_name} \
 		-command "AnnTag $name button" -width 4
	} else {
	    button $frame_name.entry -text ${short_name} \
		-command "RemoveSelectedTag $name" -width 4
	}
    } else {
	button $frame_name.entry -width 10 -relief flat
    }


    if {$sysconf(status_bar) == 0} {
	pack $frame_name.name.label -side left
    } else {
	pack $frame_name.name.cb -side left
    }
    pack $frame_name.name -side left
    pack $frame_name.entry -side right -expand no
    pack $frame_name.menu -side right -expand no -padx 10
}


### SetColor ###
proc SetColor { tag_name menubutton color} {
    global tagdata

    $menubutton config -text $color
    $menubutton config -fg $color
    set tagdata(${tag_name}-fcolor) $color
    SetTagBind
    SetData
}

### ActivateTag ###
proc ActivateTag {tag_name} {
    global screen
    
    SetData    
    ScreenCommand tag raise $tag_name
}



### SetTagBind ###
# すべてのタグについて，色とキーバインドを行なう
proc SetTagBind {} {
    global tagdata screens

    foreach each_tag $tagdata(tag-list) {
	ScreenCommand tag configure $each_tag -foreground $tagdata(${each_tag}-fcolor) \
	    -background $tagdata(${each_tag}-bcolor)
	if {[string length $tagdata(${each_tag}-bind)] > 0} {
	    foreach screen $screens {
		bind $screen $tagdata(${each_tag}-bind) "AnnTag $each_tag key"
	    }
	}
    }

}


### SetConf ###
proc SetConf {} {
    global tcl_platform data env tagdata

    # 個人の設定ファイルを開く
    switch $tcl_platform(platform) {
	unix {
	    if { [catch {source "./.tagrinrc"}] == 0 } {
		set data(config) current
	    } else {
		set tagrinrc_file [format "%s%s" $env(HOME) /.tagrinrc]
		puts $tagrinrc_file
		if { [catch {source $tagrinrc_file}] != 0 } {		
		    Message "Can't open ~/.tagrinrc \n You should save the file."
		}
		set data(config) home
	    }
	}
	windows {
	    if { [catch {source "tagrin.ini"}] != 0 } {
 		Message "Can't open tagrin.ini \n You should save the file."
	    }
	}
    }

    set tagdata(tag-list) [list]
    for {set i 1} {$i <= $tagdata(tag-list-num)} {incr i} {
	set tagdata(tag-list) [concat $tagdata(tag-list) $tagdata(tag-list${i})]
    }

}


### Initialize ###
proc Initialize {} {
    global file argc argv screen tagdata oodata

    # undolistの初期化
    InitialUndo

    if {$argc == 1 && [lindex $argv 0] == "-h"} {
	puts ""
	puts "tagrin.tcl \[-d input_file.xml\] \[-h\] \[input_file.tgr\]"
	puts " -h: show help and exit"
	puts " -d: output tgr file of input xml file, and exit"
	puts ""
	exit
    }

    # 引数に指定されたファイルを開く
    if {$argc == 1} {
	set file_name [lindex $argv 0]
	if { [catch {set file(id) [open $file_name r]}] == 0 } {
	    set file(name) $file_name
 	    ReadFile
	    SetData
	    close $file(id)
	} else {
	    Message "${file_name} couldn't opened"
	}
	return 1
    }

    if {$argc == 2 && [lindex $argv 0] == "-d"} {
	set file(import_file) [lindex $argv 1]

	if { [catch {set file(import_id) [open $file(import_file) r]}] == 0 } {
	    ImportFile
	    close $file(import_id)
	    SetData
	} else {
	    puts "ERROR: can't read input XML file."
	    exit
	}
	${oodata}::print stdout
	exit
    }


}


# -------------------- Frame --------------------

### MakePopupMenu ###
proc MakePopupMenu {} {
    global w binding
    set w(popup) .popup

    frame $w(popup) -borderwidth 2 -relief raised
#     pack $w(popup) -side top -fill x -expand no -after $w(hello)
    pack $w(popup) -side top -fill x -expand no -before $w(header)

    set file_pop $w(popup).file_pop
    set edit_pop $w(popup).edit_pop
    set view_pop $w(popup).view_pop

    menubutton $file_pop -font $w(font) -text "ファイル" -menu ${file_pop}.m
    menubutton $edit_pop -font $w(font) -text "編集" -menu ${edit_pop}.m
    menubutton $view_pop -font $w(font) -text "表示" -menu ${view_pop}.m

    pack $file_pop -side left
    pack $edit_pop -side left
    pack $view_pop -side left


    foreach i {OpenFile Save Export Reflesh Undo ISearch TSearch ResetText ToggleEditMode exit} {
	regsub {ontrol} $binding($i) "" short_${i}
    }

    menu ${file_pop}.m -font $w(font) -tearoff no
    ${file_pop}.m add command -label "開く($short_OpenFile)" -command OpenFile
    ${file_pop}.m add command -label "保存" -command SelectSave
    ${file_pop}.m add command -label "上書き保存($short_Save)" -command Save
    ${file_pop}.m add command -label "インポート" -command SelectImport
    ${file_pop}.m add command -label "エクスポート" -command SelectExport
    ${file_pop}.m add command -label "上書きエクスポート($short_Export)" -command Export
    ${file_pop}.m add command -label "終了($short_exit)" -command exit

    menu ${edit_pop}.m -font $w(font) -tearoff no
    ${edit_pop}.m add command -label "再表示($short_Reflesh)" -command Reflesh
    ${edit_pop}.m add command -label "元に戻す($short_Undo)" -command Undo
    ${edit_pop}.m add command -label "ID検索($short_ISearch)" -command ISearch
    ${edit_pop}.m add command -label "text検索($short_TSearch)" -command TSearch
    ${edit_pop}.m add command -label "モード切り替え($short_ToggleEditMode)" -command ToggleEditMode
    ${edit_pop}.m add command -label "テキスト更新($short_ResetText)" -command ResetText

    menu ${view_pop}.m -font $w(font) -tearoff no
    ${view_pop}.m add checkbutton -label "スクリーン分割" \
	-variable w(mini-screen-on) \
	-onvalue 1 -offvalue 0 -command "SetMiniScreen"
    ${view_pop}.m add checkbutton -label "Window内タグボタン" \
	-variable w(tag-button-on) \
	-onvalue 1 -offvalue 0 -command "ViewTagButton"
#     ${view_pop}.m add command -label "test" -command "destroy $w(button).pre_next.pre"

    # 初期値をセット
    set w(tag-button-on) 1
}



### ViewTagButton ###
# タグボタンについて
#「ウィンドウにうめこむ」/「別ウィンドウに表示」の変更をする
proc ViewTagButton {} {
    global w

    if {$w(tag-button-on) == 0} {
	destroy $w(bottom)

	toplevel .tagrin_button
	wm title .tagrin_button tagrin_button

	set w(bottom) .tagrin_button.bottom
	frame $w(bottom)
	pack $w(bottom) -side top
	MakeTag
	SetData

    } else {
	destroy .tagrin_button

	set w(bottom) $w(header).bottom
	frame $w(bottom)
	pack $w(bottom) -side top
	MakeTag
	SetData
    }
}


### SetMiniScreen ###
proc SetMiniScreen {} {
    global w screen1 screen2 screens

    if {$w(mini-screen-on) == 0} {
	destroy $w(screen2)
	set screens [list $screen1]
    } else {
	destroy $w(screen1)
	destroy $w(statusbar)
	MakeScreen
	MakeStatusBar
	SetBinding
	SetTagBind
	SetData
    }
}

### ISearch ###
# IdSearchを促すために，idと indexの entryをクリアする
proc ISearch {} {
    global data w

    set data(id) ""
    $w(left).index.entry delete 0 end
    Clear

    foreach i $data(atrb-tf-list) {
	$w(atrb).tf.${i} deselect
    }

    foreach i $data(atrb-text-list) {
 	$w(atrb).text.${i}.entry delete 0 end
    }
}


### TSearch ###
# screenから検索を行なう
proc TSearch {} {
    global data w

    toplevel .tsearch
    wm title .tsearch Search
    label .tsearch.message -font $w(font) -text "テキスト検索"
    entry .tsearch.entry -font $w(font) -textvariable data(search-pattern)
    bind .tsearch.entry <Return> "TSearchBody first"

    frame .tsearch.buttons
    button .tsearch.buttons.pre -font $w(font) -text "前" -command "TSearchBody previous"
    button .tsearch.buttons.next -font $w(font) -text "次" -command "TSearchBody next"
    button .tsearch.buttons.exit -text "Exit" -command "SearchExit"
    pack .tsearch.buttons.pre -side left
    pack .tsearch.buttons.next -side left
    pack .tsearch.buttons.exit -side right -padx 5
    
    pack .tsearch.message -side top -pady 2
    pack .tsearch.entry -side top -fill x -padx 10 -pady 2
    pack .tsearch.buttons -side top -pady 2
}


### SearchExit ###
# Searchを終了する
proc SearchExit {} {
    destroy .tsearch
}

### TSearchBody ###
# TSearchの本体
proc TSearchBody {flag} {
    global oodata
    
    ${oodata}::text_search $flag
}


### SearchedHilight pattern ###
# searchしたデータに色を付ける
proc SearchedHilight {args} {
    global screens w
    set pattern [lindex $args 0]
    
    foreach screen $screens {
	set start_index 1.0
	while {[set searched_begin [$screen search -regexp -- $pattern $start_index end]] != ""} {
	    regexp {([0-9]+)\.([0-9]+)} $searched_begin dummy line column
	    set searched_end \
		[format "%d.%d" $line [expr $column + [string length $pattern]]]
	    $screen tag add searched  $searched_begin $searched_end
	    set start_index $searched_end
	}
	$screen tag configure searched -foreground $w(searched-fg-color) -background $w(searched-bg-color)
    }
}


### Reflesh ###
proc Reflesh {} {
    global oodata

    set record [${oodata}::current_record]
    ${record}::set_current_id -1
    SetData
    SetStatus ""
}


### InitialUndo ###
# レコードを移動した時に，undo用のリストをリセットする
proc InitialUndo {} {
    global data

    set data(undo-flag) 0
    set data(undo-list) [list]
    set data(undo-tag-list) [list]
}


### SetUndoData ###
# edit operations (RemoveTag,SetTag)を行うたびに呼ばれ，
# 現在の recordを data(undo-list)に保存する
proc SetUndoData {} {
    global data oodata

    set data(undo-flag) 1
    set current_record [${oodata}::current_record]
    set new_record [new record {} 1]
    ${new_record}::copy $current_record

    lappend data(undo-list) $new_record
    lappend data(undo-tag-list) [list]

#     puts "----saved----"
#     ${new_record}::print
}



### Undo ###
# data(undo-list)から recordを読み出し，値をセットし直す．
proc Undo {} {
    global data oodata
    
    set num [llength $data(undo-list)]
    if {$num > 0} {
	set last_record [lindex $data(undo-list) [expr $num - 1]]
	set last_tag_list [lindex $data(undo-tag-list) [expr $num - 1]]

	if {$num > 1} {
	    set data(undo-list) [lrange $data(undo-list) 0 [expr $num - 2]]
	    set data(undo-tag-list) [lrange $data(undo-tag-list) 0 [expr $num - 2]]
	} else {
	    set data(undo-list) [list]
	    set data(undo-tag-list) [list]
	}

	${last_record}::replace_tag $last_tag_list
	${oodata}::replace_record $last_record

	SetData
	SetStatus "Undo!"
    } else {
	SetStatus "No more undo list."
    }
}



### MakeHeader ###
proc MakeHeader {} {
    global w data binding

    set w(header) .header
    frame $w(header) -borderwidth 2 -relief ridge
    pack $w(header) -side top -fill x -expand no -ipady 5

    set w(top) $w(header).top
    frame $w(top)
    pack $w(top) -side top -ipady 5

    set w(bottom) $w(header).bottom
    frame $w(bottom) -borderwidth 2 -relief ridge
    pack $w(bottom) -side top

    set w(left) $w(top).left
    set w(button) $w(top).right2
    set w(stdout) $w(header).out
    frame $w(left)
    frame $w(button)
    frame $w(stdout)

    if {$w(flat-layout) == 1} {
	pack $w(left) -side left -ipadx 10
	pack $w(button) -side left -fill x -expand no -padx 10
    } else {
	pack $w(left) -side top -ipadx 10
	pack $w(button) -side top -fill x -expand no -padx 10
    }

    if {$w(stdout-button) == 1} {
	pack $w(stdout) -side top -fill x -expand no -padx 10
    }
    button $w(stdout).button -text "stdout" -command OutputToSTDOUT
    pack $w(stdout).button -side top

    set filename $w(left).filename
    set id $w(left).id
    set index $w(left).index

    Makele $filename "file:" file(name) 6 15 ""
    Makele $id "ID:" data(id) 6 15 "IdSearch id dummy"

    frame $index
    label $index.label -font $w(font) -text "Index:" -width 6 -anchor w
    entry $index.entry -width 7 -font $w(font) -justify right
    label $index.slash -text "/" -font $w(font) 
    label $index.sum -font $w(font)
    pack $index.label -side left
    pack $index.entry -side left -fill x
    pack $index.slash -side left
    pack $index.sum -side left
    bind $index.entry <Return> "IdSearch index dummy"

    foreach i {filename id index} {
	pack [set $i] -side left -expand no -fill x
    }


# right2 (previous, next, remove button)
    frame $w(button).pre_next -borderwidth 2 -relief ridge
    scale $w(button).id_scale -from 0 -to 0 \
	-length 200 -orient horizontal -resolution 1
    pack $w(button).pre_next -side left -expand no
    pack $w(button).id_scale -side left -expand no -padx 10

    set pre_button $w(button).pre_next.pre
    set next_button $w(button).pre_next.next
    set remove_button $w(button).remove
    set mode_label_frame $w(button).mode
    set mode_label1 $w(button).mode.label1
    set mode_label2 $w(button).mode.label2

    regsub {ontrol} $binding(RemoveTag) "" short_Remove

    button $pre_button -text "<< Previous" -command Previous
    button $next_button -text "  Next  >> " -command Next
    button $remove_button -text "Remove ($short_Remove)" -command "RemoveTag button"
    frame $mode_label_frame

    label $mode_label1 -text "Mode:" -anchor w
    label $mode_label2 -textvariable data(mode) -anchor w
    
    pack $pre_button -side left
    pack $next_button -side left
    pack $remove_button -side left -padx 4
#     pack $mode_label_frame -side top -pady 2
    pack $mode_label1 -side left
    pack $mode_label2 -side left
}


### ResetIdScale ###
# 入力されたデータに基づき，scaleを調整する．
proc ResetIdScale {} {
    global w oodata data

    set num [${oodata}::num]
    if {$num < 5} {
	set interval4 1
    } else {
	set order  [expr round(log10($num))]
	set interval1 [expr $num / 5]
	set interval2 [expr $interval1 / [Expo 10 [expr $order - 1]]]
	set interval3 [expr round($interval2)]
	set interval4 [expr $interval3 * [Expo 10 [expr $order - 1]]]
    }
    $w(button).id_scale config -to [expr $num -1] -tickinterval $interval4 \
	-command "ScaleSetData" -variable ${oodata}::current_index
#    ${oodata}::current_indexはオブジェクト指向に反する

#     Index:も変更する
    $w(left).index.entry config -textvariable ${oodata}::current_index
#     合計も変更する
    $w(left).index.sum config -textvariable ${oodata}::num

#     ID:も変更する
    set data(id) [${oodata}::current_id]
}

### ScaleSetData ###
# scaleから呼ばれるコマンド．SetDataを呼ぶ．
# scaleからコマンドを呼ぶと第一引数に値が入るので，それを indexとして使う．
proc ScaleSetData { index } {
    global data

    set data(id-index) $index
    SetData
}


### Expo ###
# Expo base exp
# baseの exp乗を返す
proc Expo { base exp } {
    if { $exp == 0 } {
	return 1
    } else {
	return [expr $base * [Expo $base [expr $exp - 1]]]
    }
}



### MakeAttribute ###
# ユーザが指定した属性用のチェックボックスとリストボックスを作る．
proc MakeAttribute {} {
    global w data tagdata

    frame .under
    pack .under -side top -fill x -expand no

    set w(atrb) .under.atrb
    frame $w(atrb) -borderwidth 2 -relief ridge
    pack $w(atrb) -side top -fill x -expand no -anchor n
    set w(selfrom) .under.selfrom
    frame $w(selfrom) -borderwidth 2 -relief flat

    # リンク元がある場合のみ，リンク元選択のチェックボタンを付ける．
    if {[llength $tagdata(link-from-list)] != 0} {
	pack $w(selfrom) -side top -padx 5 -pady 5 -fill x -expand no -anchor n
    }

    if ![info exist tagdata(current-from-list)] {
	set tagdata(current-from-list) [list [lindex $tagdata(link-from-list) 0]]
    }
    foreach from_tag $tagdata(current-from-list) {
	set tagdata([format "current-from-%s" ${from_tag}]) 1
    }

    label $w(selfrom).label -font $w(font) -text "対象："
    pack $w(selfrom).label -side left -expand no -padx 2 -pady 2
    foreach tag_name $tagdata(link-from-list) {
	checkbutton $w(selfrom).cb-${tag_name} -font $w(font) -text ${tag_name} \
	    -variable tagdata(current-from-${tag_name}) \
	    -onvalue 1 -offvalue 0 -command "SetCurrentFrom"
	pack $w(selfrom).cb-${tag_name} -side left -expand no -padx 2 -pady 2
    }


    frame $w(atrb).text -borderwidth 2 -relief flat
    frame $w(atrb).tf -borderwidth 2 -relief flat

    pack $w(atrb).text -side left -fill x -expand yes -anchor n
    pack $w(atrb).tf -side left -fill x -expand yes -padx 10 -anchor n

    set data(id) "initial";

    foreach i $data(atrb-tf-list) {
 	checkbutton  $w(atrb).tf.${i} -text $i -variable data(atrb-${i}) \
 	    -font $w(font) -anchor w -command "SearchOrSetAtrb tf ${i}"
	pack $w(atrb).tf.${i} -side top -fill x
    }

    set w(tagcomment) $w(atrb).text.tagcommentxxx
    Makele $w(tagcomment) "コメント" data(tagcomment) 10 77 "SetTagComment"
    # リンク元がある場合のみ，リンク元のコメントエントリボックスを作る．
    if {[llength $tagdata(link-from-list)] != 0} {
	pack $w(tagcomment) -side top -fill x
    }

    foreach i $data(atrb-text-list) {
	Makele $w(atrb).text.${i} ${i} data(atrb-${i}) 10 77 "SearchOrSetAtrb text ${i}"
	pack $w(atrb).text.${i} -side top -fill x
    }

}



### SetCurrentFrom tag_name ###
# メニューで現在付与するタグを指定する．
proc SetCurrentFrom {} {
    global oodata
    global tagdata w
    
    set tagdata(current-from-list) [list]
    foreach tag_name $tagdata(link-from-list) {
	if {$tagdata(current-from-${tag_name}) == 1} {
	    lappend tagdata(current-from-list) $tag_name
	}
    }

    set record [${oodata}::current_record]
    set current_id [${record}::reset_from_tag_list]
    ${record}::set_current_id $current_id
    SetData
}
    

### SetTagComment ###
proc SetTagComment {} {
    global oodata

    set record [${oodata}::current_record]
    ${record}::set_tagcomment
}

### SearchOrSetAtrb ##
# type: tf / text
# atrb: selected attribute
proc SearchOrSetAtrb {type atrb} {
    global data

    # ISearchの時に $data(id)を空にするので，$data(id)が空なら Search時だと判断する
    if {[string match $data(id) ""]} {
	if {[string match $type tf]} {
	    IdSearch tf_attrib $atrb
	} else {
	    IdSearch text_attrib $atrb
	}
    } else {
	SetAtrb $atrb
    }

}


### SetAtrb ###
# 属性を入力する
proc SetAtrb {atrb} {
    global data oodata
    
    set record [${oodata}::current_record]
    ${record}::change_attribute $atrb $data(atrb-${atrb})
}


### Search Data ###
# ID, Indexの情報によりデータを検索する
# SetDataを呼び出し，データを表示させる
# IdSearch feature value
proc IdSearch { feature atrb } {
    global data oodata

    AutoSave
    InitialUndo

    # id --> data(id)
    # index --> data(id-index)
    # comment --> data(atrb-コメント)

    ${oodata}::idsearch $feature $atrb
}


### Make labeled entry ###
proc Makele { name label textval lwidth ewidth command } {
    global w

    frame $name
    label $name.label -font $w(font) -text $label -width $lwidth -anchor e
#     entry $name.entry -textvariable $textval -width $ewidth -font $w(font)
    entry $name.entry -textvariable $textval -width $ewidth -font $w(font)
    pack $name.label -side left
    pack $name.entry -side left
    bind $name.entry <Return> $command
    return $name.entry
}


# 現在選択されているテキストスクリーンのカーソルの位置を返す
proc GetScreenCursor {} {
    global w screen1 screen2

    # mini-screenが使われていなれば，screen1の値を返す
    if {$w(mini-screen-on) == 0} {
	return [$screen1 index insert]
    }

#     puts "GetScreenCursor"
#     puts [$screen1 index insert]
#     puts [$screen2 index insert]
#     puts "----------"

    if [regexp screen1 [focus]] {
# 	puts "screen1!"
	return [$screen1 index insert]
    } else {
# 	puts "screen2!"
	return [$screen2 index insert]
    }
}

# 現在選択されているテキストスクリーン中の選択領域を返す
proc GetScreenSel {} {
    global w screen1 screen2

    # mini-screenが使われていなれば，screen1の値を返す
    if {$w(mini-screen-on) == 0} {
	return [$screen1 tag ranges sel]
    }

#     puts "GetScreenSel"
#     puts [$screen1 tag ranges sel]
#     puts [$screen2 tag ranges sel]
#     puts "----------"

    if [regexp screen1 [focus]] {
# 	puts "screen1!"
	return [$screen1 tag ranges sel]
    } else {
# 	puts "screen2!"
	return [$screen2 tag ranges sel]
    }
}

# アクティブなスクリーンに対して処理を行なう
proc ScreenActiveCommand { args } {
    global screen1 screen2 w

    # mini-screenが使われていなれば，screen1の値を返す
    if {$w(mini-screen-on) == 0} {
	eval "$screen1 $args"
    }

    if [regexp screen1 [focus]] {
	eval "$screen1 $args"
    } else {
	eval "$screen2 $args"
    }
}


# 両方のスクリーンに対して処理を行なう
proc ScreenCommand { args } {
    global screen1 screen2 w

    set retval [eval "$screen1 $args"]
    if {$w(mini-screen-on) == 1} {
	eval "$screen2 $args"
    }
    return $retval
}

### Make screen ###
proc MakeScreen {} {
    global screens w

    set screens [list]
    if {$w(mini-screen-on) == 1} {
	MakeScreen2
    }
    MakeScreen1
}


### Make screen1 ###
proc MakeScreen1 {} {
    global w screen1 screens
    set w(screen1) .screen1

    frame $w(screen1) -borderwidth 2
    pack $w(screen1) -side top -fill both -expand yes

    # List Box,Scroll Bar
    set mtext $w(screen1).mtext
    set myscroll $w(screen1).myscroll
    set msbottom $w(screen1).bottom
    set mspad $w(screen1).pad

    set screen1 [text $mtext \
		    -spacing2 $w(screen-baseline) \
		    -font $w(textfont) \
		    -width $w(screen-width) \
		    -height $w(screen-height) \
		    -background $w(background) \
		    -foreground $w(foreground) \
		    -insertbackground $w(foreground) \
		    -borderwidth 2 \
		    -relief sunken \
		    -setgrid true \
		    -yscrollcommand "$myscroll set"]
    scrollbar $myscroll -orient vertical -command {$screen1 yview}
    frame $msbottom
    set pad [expr 2 * ([$myscroll cget -bd] + \
	    [$myscroll cget -highlightthickness])]
    frame $mspad -width $pad -height $pad
    pack $mspad -in $msbottom -side right
    pack $myscroll -side right -fill y -expand no
    pack $screen1 -side left -fill both -expand yes
    lappend screens $screen1
}

### Make screen2 ###
proc MakeScreen2 {} {
    global w screen2 screens
    set w(screen2) .screen2

    frame $w(screen2) -borderwidth 2
    pack $w(screen2) -side top -fill both -expand no

    # List Box,Scroll Bar
    set mtext $w(screen2).mtext
    set myscroll $w(screen2).myscroll
    set msbottom $w(screen2).bottom
    set mspad $w(screen2).pad

    set screen2 [text $mtext \
		    -spacing2 $w(screen-baseline) \
		    -font $w(textfont) \
		    -width $w(screen-width) \
		    -height $w(mini-screen-height) \
		    -background $w(background) \
		    -foreground $w(foreground) \
		    -insertbackground $w(foreground) \
		    -borderwidth 2 \
		    -relief sunken \
		    -setgrid true \
		    -yscrollcommand "$myscroll set"]
    scrollbar $myscroll -orient vertical -command {$screen2 yview}
    frame $msbottom
    set pad [expr 2 * ([$myscroll cget -bd] + \
	    [$myscroll cget -highlightthickness])]
    frame $mspad -width $pad -height $pad
    pack $mspad -in $msbottom -side right
    pack $myscroll -side right -fill y -expand no
    pack $screen2 -side left -fill both -expand yes
    lappend screens $screen2
}

# MakeStatusBar
# make status bar
proc MakeStatusBar {} {
    global w
    set w(statusbar) .statusbar

    frame $w(statusbar) -borderwidth 2 -relief sunken 
    pack $w(statusbar) -side top -fill x

    set status_bar_head $w(statusbar).status_bar_head
    set status_bar_val $w(statusbar).status_bar_val

    label $status_bar_head -text "Status: " -fg darkred -anchor w
    label $status_bar_val -textvariable w(status) -anchor w
    pack $status_bar_head -side left
    pack $status_bar_val -side left

    SetStatus ""
}



# -------------------- command -------------------- #

### SetStatus ###
# set status information into status bar
proc SetStatus {input} {
    global w

    set w(status) $input
}


### open file ###
proc OpenFile {} {
    global file

    set ftypes {
	{"tgr" {.tgr}}
	{"Other" *}
    }
    set file_name [tk_getOpenFile -filetypes $ftypes]

    if { [catch {set file(id) [open $file_name r]}] == 0 } {
	set file(name) $file_name
	ReadFile
	SetData
	close $file(id)
    }
}


### read from file ###
proc ReadFile {} {
    global file oodata w

    SetStatus "Reading..."
    set oodata [[new document {} 1]::construct]

    while { [gets $file(id) line] >= 0 } {
	if { [regexp {^<text id=(.+)>$} $line dummy id ] } {
 	    set rec [[new record {} 1]::construct $id]

	    set buffer ""
	    
	    gets $file(id) in_line
	    while { ![regexp {^</text>} $in_line] } {
		switch -regexp -- $in_line {
		    {^#} {
		    }
		    {^<tags>} {
			set in_line [gets $file(id)]
			while { ![regexp {^</tags>} $in_line] } {
			    set tag_info [split $in_line "\t"]
			    set tag_name [lindex $tag_info 0]
			    set tag_range [lindex $tag_info 2]
			    regexp {\[([0-9.]+), ([0-9.]+)\]} $in_line dummy from_value to_value
			    set atrb_list [lindex $tag_info 3]

# 			    puts $tag_info
# 			    puts [lindex $tag_info 0]
# 			    puts [lindex $tag_info 1]
# 			    puts "$from_value, $to_value"
#  			    puts $atrb_list

			    set atag [[new tag {} 1]::construct \
					  $tag_name \
					  [${rec}::next_id] \
					  $from_value \
					  $to_value \
					  $atrb_list]
			    if {$atag != 0} {
				# タグを追加する
				${rec}::append_tag ${atag} read
			    }
			    set in_line [gets $file(id)]
			}
		    }
		    {^<contents>} {
			set in_line [gets $file(id)]
			while { ![regexp {^</contents>} $in_line] } {
			    set buffer [format "%s%s\n" $buffer $in_line]
			    set in_line [gets $file(id)]
			}
			${rec}::set_contents $buffer
		    }
		    {^<attribute>} {
			set in_line [gets $file(id)]
			while { ![regexp {^</attribute>} $in_line] } {
			    set atrb_set [split [string trim $in_line]]
			    set atribute [lindex $atrb_set 0]
			    set value [join [lrange $atrb_set 1 end]]
			    set data(${id}-$atribute) $value
			    ${rec}::add_attribute $atribute $value
			    set in_line [gets $file(id)]
			}
		    }
		    {^<lastid>} {
			set in_line [gets $file(id)]
			while { ![regexp {^</lastid>} $in_line] } {
			    ${rec}::set_lastid $in_line
			    set in_line [gets $file(id)]
			}
			${rec}::set_contents $buffer
		    }

		}
		gets $file(id) in_line
	    }
	    ${oodata}::append_record ${rec} read
	}
    }

#    ${oodata}::print
    ResetIdScale
    SetStatus "Reading... done."
}


### SelectImport ###
proc SelectImport {} {
    global file

    if [info exist file(import_file)] {
	set file_import_file $file(import_file)
    }
    set ftypes {
	{"xml" {.xml}}
	{"Other" *}
    }
    set file(import_file) [tk_getOpenFile -filetypes $ftypes]
#    set file(import_file) "sample.xml"
    
    if { [catch {set file(import_id) [open $file(import_file) r]}] == 0 } {
	ImportFile
	close $file(import_id)
	SetData
    }
}


### ImportFile ###
proc ImportFile {} {
    global file tagdata stack oodata

    SetStatus "Import..."
    set oodata [[new document {} 1]::construct]

    while { [gets $file(import_id) line] >= 0 } {
	if { [regexp {^<text (.+)>$} $line dummy attribs ] } {
	    set attrib_list [list]
	    foreach attrib_set [split $attribs ";"] {
		regexp {(.+)=(.+)$} $attrib_set dummy attrib val
		if [string match $attrib "id"] {
		    set rec [[new record {} 1]::construct $val]
		}
		lappend attrib_list [list $attrib $val]
	    }

	    foreach attrib_set ${attrib_list} {
		if [string match [lindex $attrib_set 0] "lastid"] {
		    ${rec}::set_lastid [lindex $attrib_set 1]
		} else {
		    ${rec}::add_attribute [lindex $attrib_set 0] [lindex $attrib_set 1]
		}
	    }

	    set buffer ""
	    set line_num 1

	    gets $file(import_id) in_line
 	    # -------------------- 一行ずつ読み込む -------------------- #
	    while { ![regexp {^</text>} $in_line] } {
		set buffer [format "%s%s\n" $buffer $in_line]
		set offset 0
		set line_buffer $in_line

		# 初期化
		foreach each_tag $tagdata(tag-list) {
		    NewStack $each_tag
		}
		
		while { [regexp {<[^>]+>} $line_buffer tag_string] } {
#  		    puts "in: $tag_string"
		    set tag_begin [string first $tag_string $line_buffer]
		    regsub {<[^>]+>} $line_buffer "" line_buffer
		    set tag_name [lindex [split [string trim $tag_string {< > /}] " "] 0]
		    set tag_atrb [string trim $tag_string {< > /}]

		    if {[regexp {</} $tag_string ]} {
			# 終了タグの場合
			set pop_value [Pop $tag_name]
			set from_value [lindex [split $pop_value ":"] 0]
			set to_value [format "%d.%d" $line_num [expr $tag_begin]]
			set tag_value [lindex [split $pop_value ":"] 1]
			if { [string first " " $tag_value] != -1 } {
			    set atrb_list [string range $tag_value [expr [string first " " $tag_value] + 1] end]
			} else {
			    set atrb_list ""
			}

			set atag [[new tag {} 1]::construct \
				      $tag_name \
				      [${rec}::next_id] \
				      $from_value \
				      $to_value \
				      $atrb_list]
			if {$atag != 0} { ${rec}::append_tag ${atag} read}

		    } else {
			# 開始タグの場合，スタックに入れる．
			Push $tag_name [format "%d.%d:%s" $line_num [expr $tag_begin] $tag_atrb]
		    }
		}
		# -------------------- 一行ずつ読み込む終了 -------------------- #
		set line_num [expr $line_num + 1]
		gets $file(import_id) in_line
	    }

	    # --- 1レコードの読み込み終了
 	    regsub -all {<[^>]+>} $buffer "" new_buffer
	    ${rec}::set_contents $new_buffer
	    ${oodata}::append_record ${rec}

	}
    }

#     ${oodata}::print
    ResetIdScale
    SetStatus "Import... done."
}


### Lremove ###
# Lremove $list $val
# $listから $valを除いたリストを返す
proc Lremove {list val} {
    set ret_val [list]

    foreach i $list {
	if { ![string match $i $val] } {
	    lappend ret_val $i
	}
    }
    return $ret_val
}


### Position_val ###
# int.int形式のインデックスを引数として受け取り，整数に展開して返す
proc Position_val {position} {
    global data
    regexp {([0-9]+)\.([0-9]+)} $position dummy line column
    return [expr $line * $data(max-char-in-line) + $column]
}


# スタックの使い方
# 配列名 stackを globalする
# NewStack stack_name
### NewStack ###
proc NewStack {stack_name} {
    global stack

    set stack($stack_name) [list]
}

### Push ###
proc Push {stack_name val} {
    global stack tagdata

    if {[lsearch $tagdata(tag-list) $stack_name] == -1} {
	return 0;
    }
    return [set stack($stack_name) [linsert $stack($stack_name) end $val]]
}

### Pop ###
proc Pop {stack_name} {
    global stack

    set length [llength $stack($stack_name)]

    switch $length {
	0 {
	    set ret_val NULL
	}
	1 {
	    set ret_val [lindex $stack($stack_name) end]
	    set stack($stack_name) [list]
	}
	default {
	    set ret_val [lindex $stack($stack_name) end]
	    set stack($stack_name) [lrange $stack($stack_name) 0 [expr $length - 2]]
	}
    }
    return $ret_val
}


### set data ###
# 表示
proc SetData {} {
    global screen tagdata w oodata data screen1 screen2

    if ![info exist oodata] { return 0 }

#     set time_start [clock clicks -milliseconds]

#     set w(position) [ScreenCommand index insert]
    set w(scroll1) [$screen1 yview]
    if {$w(mini-screen-on) == 1} {
	set w(scroll2) [$screen2 yview]
    }

    Clear
    # searched hilightを元に戻す
    ScreenCommand tag delete searched
    SetStatus ""
    set record [${oodata}::current_record]
    set data(id) [${oodata}::current_id]

    # タグボタンの背景のハイライトを消去
    foreach tagname $tagdata(tag-list) {
	$tagdata(${tagname}-cb) config -background gray85
    }

    #--------------------------------------------------
    # ここまで消去

    # テキストの表示
    Screen [${record}::contents]

    # タグの付与
    if {$w(edit-mode) == 1} {
	set edit_mode edit
    } else {
	set edit_mode tagging
    }
    if {$w(unfocus) == 1} {
	set unfocus 1
	set w(unfocus) 0
    } else {
	set unfocus 0
    }
    ${record}::set_tags ${edit_mode} ${unfocus}



    # 属性の付与
    ${record}::set_attribute
    # タグコメントの付与
    ${record}::display_tagcomment

#     ${record}::print

#     tk::TextSetCursor ScreenCommand ${w(position)}
    $screen1 yview moveto [lindex $w(scroll1) 0]
    if {$w(mini-screen-on) == 1} {
	$screen2 yview moveto [lindex $w(scroll2) 0]
    }


#     set time_end [clock clicks -milliseconds]
#     puts [format "- time SetData: %d ms" [expr $time_end - $time_start]]
}


### $tagdata(link-from)タグのIDを引数として，そのタグをハイライトする
proc SelectNewData {newid} {
    global oodata

    set record [${oodata}::current_record]
    set ret_val [${record}::set_current_id $newid]

    if {$ret_val == 1} {
	SetData
    }
}


### NextNewData ###
# リンク元のタグを一つ次に移動する
proc NextNewData {} {
    global oodata

    if ![info exist oodata] { return 0 }

    set record [${oodata}::current_record]
    ${record}::next_link_from_tag
    ${record}::reset_current_selected_tag
    SetData
    return -code break 0
}


### PreviousNewData ###
# リンク元のタグを一つ前に移動する
proc PreviousNewData {} {
    global oodata

    if ![info exist oodata] { return 0 }

    set record [${oodata}::current_record]
    ${record}::previous_link_from_tag
    ${record}::reset_current_selected_tag
    SetData
    return -code break 0
}


### Usort ###
# sortして，uniqをとる
proc Usort {input_list} {
    set new_list [lsort $input_list]
    set ret_list [list]
    set before "NULL"
    foreach i $new_list {
	if {$i != $before} {
	    lappend ret_list $i
	    set before $i
	}
    }
    return $ret_list
}


### next data ###
proc Next {} {
    global data oodata

    if ![info exist oodata] {
	return 0
    }

    # Nextする前に，現在の attributeの値を記憶する．
    foreach i $data(atrb-text-list) {
	SetAtrb ${i}
    }

    AutoSave
    InitialUndo

    ${oodata}::next
    SetData
}

### previous data ###
proc Previous {} {
    global data oodata

    if ![info exist oodata] {
	return 0
    }

    # Previousする前に，現在の attributeの値を記憶する．
    foreach i $data(atrb-text-list) {
	SetAtrb ${i}
    }

    AutoSave
    InitialUndo

    ${oodata}::previous
    SetData
}



### Clear ###
proc Clear {} {
    global screen

    ScreenCommand delete 1.0 end
}



### RemoveTag ###
# カーソルの下または範囲指定されているタグの領域を削除する
proc RemoveTag {key_or_button} {
    global tagdata oodata

    SetUndoData

    set record [${oodata}::current_record]
    ${record}::remove_tag [GetScreenSel] [list]

    selection clear
    SetData

    if {[string compare $key_or_button key] == 0} {
	return -code break 0
    }
}


### RemoveSelectedTag ###
# 選択したタグだけを削除する
proc RemoveSelectedTag {name} {
    global tagdata oodata

    SetUndoData

    foreach tag $tagdata(tag-list) {
	set tmp($tag) $tagdata(${tag}-status)
	set tagdata(${tag}-status) 0
    }
    set tagdata(${name}-status) 1

    set record [${oodata}::current_record]
    ${record}::remove_tag [GetScreenSel] [list]

    foreach tag $tagdata(tag-list) {
	set tagdata(${tag}-status) $tmp($tag) 
    }

    selection clear
    SetData
}



### Print to screen ###
proc Screen { monstr } {
    ScreenCommand insert end $monstr
#     ScreenCommand insert end "\n"
}


### AnnTag ###
# 選択範囲にタグをふる
# もしテキスト中に選択された領域があれば SetTagを呼び，そうでなければ
# CopyTagを呼ぶ
proc AnnTag { tag_name key_or_button } {

    SetUndoData

#     set time_start [clock clicks -milliseconds]

    if {[string length [GetScreenSel]] > 0} {
	SetTag $tag_name
    } else {
	CopyTag $tag_name
    }

#     set time_end [clock clicks -milliseconds]
#     puts [format "- time AnnTag: %d ms" [expr $time_end - $time_start]]

    if {[string compare $key_or_button key] == 0} {
	return -code break 0
    }
}
 

### Set Tag ###
# 選択範囲にタグをふる
proc SetTag { tag_name } {
    global tagdata oodata w

    if {$w(edit-mode) == 1} {
	Message "Please change the mode to \"Tagging mode\"."
	return 1
    }

    set record [${oodata}::current_record]
    if {$tagdata(${tag_name}-status) == 1} {
	catch { ScreenCommand tag add $tag_name sel.first sel.last }
	ScreenCommand tag raise $tag_name

	set select_range [GetScreenSel]
	set sel_from [lindex $select_range 0]
	set sel_to [lindex $select_range 1]

	set atag [[new tag {} 1]::construct $tag_name [${record}::next_id] $sel_from $sel_to]
	${record}::append_tag ${atag} tagging

 	SetData
    }

    selection clear
}


### CopyTag ###
# ポインタをおいた場所にあるタグの領域に指定したタグをはる
proc CopyTag { tag_name } {
    global tagdata oodata

    if {$tagdata(${tag_name}-status) == 1} {

	# todo
	# oncursorになるタグが複数あった場合，それらの UNION
	# の領域にタグをふるべき．

	set record [${oodata}::current_record]
	
	for {set i 0} {$i < [${record}::next_id]} {incr i} {
	    set tag [${record}::get_a_tag $i]

	    if ![string match $tag NULL] {
		set cursor [GetScreenCursor]
		if [${tag}::on_cursor $cursor] {
		    ${tag}::add_sel
		    SetTag $tag_name
		    break
		}
	    }
	}
    }
}


### SelectSave ###
proc SelectSave {} {
    global file

    if [info exist file(name)] {
	set file_name $file(name)
    }
    set ftypes {
	{"sample" {.tgr}}
	{"Other" *}
    }
    set file(name) [tk_getSaveFile -defaultextension ".tgr" -filetypes $ftypes]
    if { [string length $file(name)] == 0 } {
	if [info exist file(name)] {
	    set file(name) $file_name
	}
    } else {
	Save
    }
}


### AutoSave ###
# Previous, Next, IdSearchが実行されると，前の状態を保存する．
proc AutoSave {} {
    global file data sysconf

    # todo
    # Saveをしたときに，backファイルは消す

    if {$sysconf(autosave) == 1} {
	# undo_stackを見て，値が入っていれば Saveする
	set num [llength $data(undo-list)]
	if {$num > 0} {
	    set file(autosave) "$file(name)_back"
	    Save
	    set file(autosave) ""
	    # 	puts "auto saved"
	} else {
	    # 	puts "empty"
	}
    }
}

### Save ###
proc Save {} {
    global data file oodata

    # Saveする前に，現在の attributeの値を記憶する．
    foreach i $data(atrb-text-list) {
	SetAtrb ${i}
    }

    if {[info exist file(autosave)] && [string length $file(autosave)] > 0} {
	set filename $file(autosave)
    } else {
	set filename $file(name)
    }

    if { [catch {set file(id) [open $filename w]}] == 0 } {
	SetStatus "Saving..."
	${oodata}::print $file(id)
	close $file(id)
	SetStatus "Saving... done."
    } else {
	Message "Can't Save"
    }
}


### SelectExport ###
proc SelectExport {} {
    global file
    
    if [info exist file(export_file)] {
	set file_export_file $file(export_file)
    }
    set ftypes {
	{"XML" {.xml}}
	{"Other" *}
    }
    set file(export_file) [tk_getSaveFile -defaultextension ".xml" -filetypes $ftypes]
    if { [string length $file(export_file)] == 0 } {
	if [info exist file_export_file] {
	    set file(export_file) $file_export_file
	}
    } else {
	Export
    }
}


### Export ###
proc Export {} {
    global data screen1 tagdata file oodata

    # Exportする前に，現在の attributeの値を記憶する．
    foreach i $data(atrb-text-list) {
	SetAtrb ${i}
    }

#     set file(export_file) "test.xml"
    if { [catch {set file(export_id) [open $file(export_file) w]}] == 0 } {
	SetStatus "Exporting..."
	${oodata}::export $file(export_id)
	close $file(export_id)
	SetStatus "Exporting... done."
    } else {
	Message "Can't Export"
    }

    set record [${oodata}::current_record]
    ${record}::set_current_id -1
    SetData
}


### ToggleEditMode ###
# EditModeに入る
proc ToggleEditMode {} {
    global w

    if {$w(edit-mode) == 1} {
	ResetText
	set w(edit-mode) 0
	SetData
	SetStatus "Tagging mode"
    } else {
	set w(edit-mode) 1
	SetData
	SetStatus "Edit mode"
    }
}



### ExistMatch ###
# ExistMatch str1 str2
# str1と str2が空文字列でなく，厳密に等しいときに trueを返す
proc ExistMatch {str1 str2} {
    if { [string match $str1 $str2] && [string match $str2 $str1] && [string length $str1] > 0 }  {
	return 1
    } else {
	return 0
    }
}


### OutputToSTDOUT ###
# 現在選択されているタグとそれにリンクされているタグの情報を出力する
proc OutputToSTDOUT {} {
    global tagdata oodata
    set record [${oodata}::current_record]
    ${record}::show_current_tag stdout
}


### CalcAscii ###
# 開始タグと終了タグが重なった場合，タグの文字列でソートするための数字を返す．
# 先頭から 3文字だけを考慮している．
proc CalcAscii {in_string} {
    set ret_val ""

    for {set i 0} {$i < 3} {incr i} {
#  	puts [scan [string index $in_string $i] "%c"]
	set c_in_ascii [scan [string index $in_string $i] "%c"]
	if { [string match $c_in_ascii ""] } {
	    set ret_val [format "%s00000" $ret_val]
	} else {
	    set ret_val [format "%s%05d" $ret_val $c_in_ascii]
	}
    }
    return [expr 1000000000000000 - [string trimleft $ret_val "0"]]
}

### Message ###
proc Message {message} {
    global w
    tk_messageBox -title "Message" -message $message -type ok
}


### YN_Message ###
proc YN_Message {message} {
    global w
    return [tk_messageBox -title "Message" -message $message -type yesno]
}



### ResetText ###
# 現在のテキストの内容とタグの位置を更新する．
proc ResetText {} {
    global oodata w

    if {$w(edit-mode) == 0} {
	Message "Please change the mode to \"Edit mode\"."
 	Reflesh
	return 1
    }

    SetUndoData

    set record [${oodata}::current_record]
    ${record}::reset_text
}


proc Unfocus {} {
    global w

    focus $w(left)
    set w(unfocus) 1
    SetData
}


# -------------------- Bind --------------------
### Set binding ###
proc SetBinding {} {
    global w screens binding

    foreach i { OpenFile Save Export Reflesh Undo ISearch TSearch ResetText ToggleEditMode Unfocus exit } {
	bind all <$binding($i)> $i
    }

    foreach screen $screens {
	bind $screen <$binding(RemoveTag)> "RemoveTag key"
	bind $screen <Tab> NextNewData
	bind $screen <<PrevWindow>> PreviousNewData
	#     bind [set $screen] <Double-Button-1> ""
    }

    bind all <Tab> NextNewData
    bind all <<PrevWindow>> PreviousNewData

    bind all <Button-5> Next
    bind all <Button-4> Previous

    bind all <Next> Next
    bind all <Prior> Previous
}

### Call Main ###
Main

