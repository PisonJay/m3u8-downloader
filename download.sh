#!/usr/bin/zsh
if [ "$1" = "" ];then
    echo 'usage:' $0 '<playlist url>'
    exit
else
    url=$1
fi

echo Downloading $url

playlist=${url##*/}
basedir=${url/%$playlist/}

echo playlist: $playlist
echo basedir: $basedir

if [ ! -f $playlist ];then
    aria2c $basedir$playlist
fi

encryption=$(grep '^#EXT-X-KEY' $playlist)

echo encryption: $encryption

if [ "$encryption" = "" ];then
    echo no encryption
else
    keyfile=$(echo $encryption | sed 's/.*URI="\(.*\)".*/\1/g')
    echo $keyfile
    if [ ! -f $keyfile ];then
        aria2c $basedir$keyfile
    fi
    key=$(xxd -p $keyfile)
    iv=$(echo $encryption | sed 's/.*IV=0x\([^,]*\).*/\1/g')
fi

if [ -f urls.txt ];then
    rm urls.txt
fi

if [ -f files.txt ];then
    rm files.txt
fi

for file in $(grep '\.ts$' $playlist)
do
    echo $basedir$file >> urls.txt
    echo file $file >> files.txt
done

# download
mkdir -p origin
cd origin

while : ;do
    rm ../urls.txt
    for file in $(grep '\.ts$' ../$playlist)
    do
        if [ -f $file ];then
            if [ -f $file.aria2 ];then
                echo $basedir$file >> ../urls.txt
            fi
        else
            echo $basedir$file >> ../urls.txt
        fi
    done
    if [ -f ../urls.txt ];then
        aria2c -j2 -c -i ../urls.txt
    else
        break
    fi
done
decode() {
    openssl aes-128-cbc -d -in $1 -out $1-dec -nosalt -iv $iv -K $key && mv $1-dec $1
}

if [ ! "$encryption" = "" ];then
    for file in $(grep '\.ts$' ../$playlist)
    do
        decode $file
    done
fi

ffmpeg -f concat -i ../files.txt -c copy ../${playlist/%\.m3u8/}.mp4
cd ..
# rm -rf origin