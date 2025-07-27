java -version

if [ -f "mcdl" ]; then
    echo "Not redownloading mcdl"
else
    echo "Downloading mcdl"
    wget https://github.com/Meshiest/mcdl/releases/latest/download/mcdl
    chmod +x mcdl
fi

if [ -e "versions/$1" ]; then
    rm -r versions/$1
fi

mkdir -p versions/$1
cd versions/$1

../../mcdl $1

java -DbundlerMainClass="net.minecraft.data.Main" -jar server.jar --all

rm server.jar
rm -r libraries
rm -r logs
rm -r versions
cp -r generated/* .