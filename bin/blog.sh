#!/usr/bin/env bash

BLOG_BUILD_DIR=${BLOG_BUILD_DIR:-build}
BLOG_TITLE=${BLOG_TITLE-Title}
BLOG_DESCRIPTION=${BLOG_DESCRIPTION-"Default title"}
BLOG_LONG_DESCRIPTION=${BLOG_LONG_DESCRIPTION-"Long description"}
BLOG_HTTP_URL=${BLOG_HTTP_URL-"https://example.com"}

ENOENT=2

declare -A PACKAGE_MANAGERS=(
    [brew]="brew install"
    [apt]="sudo apt install"
    [yum]="yum install"
    [pacman]="pacman -S"
    [pkg]="pkg install"
)

install_package () {
    for package_manager in "${!PACKAGE_MANAGERS[@]}"; do
        if hash "$package_manager" 2> /dev/null; then
            ${PACKAGE_MANAGERS[$package_manager]} "$@"
            return 0
        fi
    done

    echo "i: can't find suitable package manager"
    echo "i: available package managers:"
    for package_manager in "${!PACKAGE_MANAGERS[@]}"; do
        echo "i:     $package_manager"
    done
    return $ENOENT
}

dependency () {
    local exe="$1"; shift || return
    local package="${1:-$exe}"; shift
    hash "$exe" 2> /dev/null || install_package "$package"
}

check_dependencies () {
    dependency pandoc
}

format_date () {
    sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2}) .*/\1\/\2\/\3/'
}

render_post () {
    local -n post="$1"; shift || return
    local content="$1"; shift || return

    cat <<____EOF
    <div class="post post-full">
          <div class="wrapper post-img-wrapper">
          <div class="post-header-wrapper">
            <header class="post-header">

            <h1 class="post-h">

            <a class="post-link" href="${post[url]}">${post[title]}</a>

            </h1>

            <div class="post-meta">
                <span>$(echo ${post[date]} | format_date)</span>
                <span class="post-tags">
                $(
                    for tag in ${post[tags]}; do
                        echo "<a class="post-tag" href="#">$tag</a>"
                    done
                )
                </span>
            </div>

            </header>
          </div>
        </div>


        <div class="wrapper">

        <div class="post-content">${content}</div>

        <div class="navigation">
            <div>
                <div class="prev-post">
                $(
                    if [[ -n ${PAGE_NEXT[url]+x} ]]; then
                        echo "<div>Next post</div>"
                        echo "<a href="${PAGE_NEXT[url]}">${PAGE_NEXT[title]}</a>"
                    else
                        echo "&nbsp;"
                    fi
                )
                </div>
                <div class="next-post">
                $(
                    if [[ -n ${PAGE_PREV[url]+x} ]]; then
                        echo "<div>Previous post</div>"
                        echo "<a href="${PAGE_PREV[url]}">${PAGE_PREV[title]}</a>"
                    else
                        echo "&nbsp;"
                    fi
                )
                </div>
                <div class="cf"></div>
            </div>

            <div class="all-posts-link">
                <a href="/">[see all posts]</a>
            </div>
        </div>
        </div>
    </div>
____EOF
}

with_layout_default () {
    cat <<____EOF
    <!DOCTYPE html>
    <html lang="en">

    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="theme-color" content="#0276f6">
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">

        $(
            if [[ -z ${PAGE[title]} ]]; then
                echo "<title>${BLOG_TITLE} | ${BLOG_DESCRIPTION}</title>"
            else
                echo "<title>${PAGE[title]} | ${BLOG_TITLE}</title>"
            fi
        )

        <meta name="generator" content="blog.sh" />
        <meta property="og:title" content="${PAGE[title]:-${BLOG_TITLE}}" />
        <meta property="og:locale" content="en_US" />

        <meta name="description" content="${page[description]:-A public domain blog about Bash}" />
        <meta property="og:description" content="${page[description]:-A public domain blog about Bash}" />

        <link rel="canonical" href="${PAGE[absolute_url]}" />
        <meta property="og:url" content="${PAGE[absolute_url]}" />

        <meta property="og:site_name" content="${BLOG_TITLE}" />
        <link rel="next" href="http://czarnota.github.io/page/2/index.html" />
        <script type="application/ld+json">
        {"@type":"WebSite","url":"http://czarnota.github.io/","headline":"${BLOG_TITLE}","description":"${BLOG_LONG_DESCRIPTION}","name":"${BLOG_TITLE}","@context":"http://schema.org"}</script>
          <link rel="stylesheet" href="/assets/main.css">
         <link rel="icon" type="image/png" href="/assets/favicon.ico">
      </head>
      <body>
        <div class="content">
            <main aria-label="Content">
                $(cat)
            </main>

            <footer>
                <div class="copyright">
                    <a href="/uncopyright/" class="about-link">uncopyright</a>
                </div>
            </footer>
        </div>

      </body>

    </html>
____EOF
}

with_layout_post () {
    with_layout_default <<____EOF
    <article class="post h-entry" itemscope itemtype="http://schema.org/BlogPosting">
        $(render_post PAGE "$(cat)")
        <a class="u-url" href="/${PAGE[url]}" hidden></a>
    </article>

____EOF
}

fmatter_parse () {
    local file="$1"; shift || return
    local -n out="$1"; shift || return

    {
        local last_key key val
        while read key val; do
            key=${key/:/}
            if [[ $key == - ]]; then
                out[$last_key]="$(echo ${out[$last_key]} $val)"
            else
                last_key=$key
            fi

            if [[ $key == title ]]; then
                out[title]=$(echo "$val" | sed -E 's/^\"(.*)\"$/\1/')
            else
                out[$key]="$val"
            fi

        done
    } < <(grep -E -B 1000 -- "^---$" < $file)

    out[content]="$(pandoc -i "$file" -o -)"

    local target="$(sed -E '
        s/([0-9]{4})-([0-9]{2})-([0-9]{2})-/\1\/\2\/\3\//
        s/\.md$/\.html/
    ' <<< "$file")"

    out[target]="$target"
    out[url]="/$target"
    out[absolute_url]="$BLOG_HTTP_URL/$target"
}

array_copy () {
    local -n dst="$1"; shift || return
    local -n src="$1"; shift || return

    dst=()

    for k in "${!src[@]}"; do
        dst[$k]="${src[$k]}"
    done
}

array_print_lines () {
    local -n arr="$1"; shift || return

    for item in "${arr[@]}"; do
        echo "$item"
    done
}

paginate () {
    local -n src="$1"; shift || return
    local -n dst="$1"; shift || return
    local per_page="$1"; shift || return

    local i=0;
    local buff;
    for page in "${src[@]}"; do
        buff+=" $page"
        if (( i + 1 >= per_page )); then
            dst+=("$buff")
            buff=""
            (( i = 0 ))
        else
            ((i++))
        fi
    done

    if [[ -n $buff ]]; then
        dst+=("$buff")
    fi
}

render_archives () {
    with_layout_default <<____EOF
        <div class="wrapper">
            <h1 class="all-posts-h">${BLOG_TITLE}</h1>
            <span class="all-posts-about">${BLOG_DESCRIPTION}</span>
            <ul class="all-posts">
                $(
                    for i in ${page_numbers[@]}; do
                        local -n post=PAGE_$i
                        echo "<li><a href="${post[url]}">${post[title]}</a> <span class="all-posts-date">$(echo ${post[date]} | format_date)</span></li>"
                    done
                )
            </ul>
        </div>
____EOF
}

render_about () {
    with_layout_default <<____EOF
        <div class="about wrapper">
        <h1 class="all-posts-h">${BLOG_TITLE}</h1>
        <span class="all-posts-about">
        ${BLOG_DESCRIPTION}
        </span>

        <p>
        This blog is Uncopyrighted. Its authors, have released all claims on copyright and has put all the content of this blog into the public domain.

        No permission is needed to copy, distribute, or modify the content of this site. Credit is appreciated but not required.
        </p>

        <h4>Terms and Conditions for Copying, Distribution and Modification</h4>

        <ul>
        <li>0. Do whatever the hell you like.</li>
        </ul>
        </p>
____EOF
}

all_posts () {
    for post in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*; do
        echo $post
    done | sort -r
}

save_as () {
    local destination="$1"; shift || return
    local directory="$(dirname "$destination")"

    mkdir -p "$directory"
    
    cat > "$destination"
}

read_blog_tags () {
    local -n out="$1"; shift || return
    local -n all="$1"; shift || return

    local tmp_tags=()

    for i in "${all[@]}"; do
        local -n page=PAGE_$i

        for tag in ${page[tags]}; do
            tmp_tags+=("$tag")
        done
    done

    out=($(array_print_lines tmp_tags | sort | uniq))
}

filter_pages_by_tag () {
    local -n out="$1"; shift || return
    local -n all="$1"; shift || return
    local tag="$1"; shift || return

    out=()

    for page_number in "${all[@]}"; do
        local -n post=PAGE_$page_number
        if ! [[ ${post[tags]} =~ \ *$tag\ * ]]; then
            continue
        fi
        out+=($page_number)
    done
}

main () {
    check_dependencies 

    echo "blog.sh: blog.sh - static site generator written in Bash"
    echo "blog.sh: Version 0.1.0"
    echo "blog.sh: Uncopyrighted. Public domain."
    echo -n "blog.sh: Transforming posts"
    local i=0;

    for post in $(all_posts); do
        echo -n "."

        local -A PAGE_$i
        fmatter_parse "$post" PAGE_$i

        ((i++))
    done

    all_page_numbers=($(seq 0 $(( i - 1 ))))

    # Render every post page
    for i in ${all_page_numbers[@]}; do
        local -n PAGE=PAGE_$i
        if (( i > 0 )); then
            local -n PAGE_NEXT=PAGE_$((i - 1))
        fi
        if (( i < ${#all_page_numbers[@]} )); then
            local -n PAGE_PREV=PAGE_$((i + 1))
        fi
        echo "${PAGE[content]}" | with_layout_post | save_as "$BLOG_BUILD_DIR/${PAGE[target]}"
        unset -n PAGE
        unset -n PAGE_PREV
        unset -n PAGE_NEXT
    done

    echo ok

    (
        local -A PAGE=(
            [target]="index.html"
            [url]="/index.html"
            [absolute_url]="$BLOG_HTTP_URL/index.html"
        )
        array_copy page_numbers all_page_numbers
        render_archives | save_as "$BLOG_BUILD_DIR/index.html"
    )

    (
        local -A PAGE=(
            [target]="about/index.html"
            [url]="/unopyright/"
            [title]="About"
            [absolute_url]="$BLOG_HTTP_URL/uncopyright/"
        )
        render_about | save_as "$BLOG_BUILD_DIR/uncopyright/index.html"
    )

    rm -fr $BLOG_BUILD_DIR/assets
    cp -fr assets $BLOG_BUILD_DIR/assets

}

declare -A COMMANDS=(
    [main]=main
)

"${COMMANDS["${1:-main}"]:-${COMMANDS[main]}}" "$@"

