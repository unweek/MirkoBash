#!/bin/bash

author="Bielecki"
version="0.0.3"
lastupdate="19.02.2019"

## Changelog
#
# 0.0.3 - moved config data to ~/.config/mirkobash/, added polish comments
# 0.0.2 - added hot page scrapping
# 0.0.1 - initial version - post and quick login with userkey updating
#
##

main() {	# funkcja startowa, wywoływana na końcu skryptu, by wpierw załadować ustawienia

if [ -n "$1" ]; then		# użytkownik podał parametr, więc sprawdźmy który to i przenieśmy do odpowiedniej funkcji
	case "$1" in
	--login)	login
		;;
	--post)	shift && post "$@"
		;;
	--hot)	shift && hot "$@"
		;;
	--help | --usage | -h | -\? | -u)	usage; exit 0
		;;
	* )	usage; exit 1
		;;
	esac
	shift
fi
}


usage() {	# pomoc
printf "%b\n" "MirkoBash v$version by $author" "Last updated: $lastupdate\n"
printf "%s\n" "Dostępne opcje:" \
	"--login: logowanie użytkownika, renowacja klucza" \
	"--post \"(zawartość)\": wrzuca na mirko post z podaną zawartością" \
	"--hot (strona) (czas: 6, 12 lub 24): zwraca ID, datę i ilość plusów postów z gorących"
}

if [ -z "$1" ]; then usage; fi	# sprawdzamy czy użytkownik podał parametry, jeśli nie to wyrzucamy usage

## Sprawdzamy czy config w ogóle istnieje
if [ ! -d "$HOME/.config/mirkobash" ]; then	# folder instnieje?
	mkdir "$HOME/.config/mirkobash"
else	# jeśli nie ma configu, to stwórzmy nowy
	if [ ! -s "$HOME/.config/mirkobash/mirkobash.conf" ]; then
		printf "
## Config for MirkoBash
secret=\"\"
appkey=\"\"
token=\"\"
userkey=\"\"
" > "$HOME/.config/mirkobash/mirkobash.conf"
	fi
fi

## Load settings:
. "$HOME/.config/mirkobash/mirkobash.conf"		# ładujemy config
if [ -z "$secret" -o -z "$appkey" -o -z "$token" ]; then	#sprawdzamy czy użytkownik uzupełnił config swoimi danymi
	echo "Uzupelnij konfigurację w ~/.config/mirkobash/mirkobash.conf, wpisujac dane z tworzenia aplikacji wykopu"
	exit 1
fi


sign() {	# podpisywanie żądań, wywołując funkcję zyskujemy czytelność
md5all=$(echo -n "$secret$url$data2" | md5sum | awk '{print $1}')
}


hot() {		# funkcja wyświetlania gorących
if [ -z "$1" -o -z "$2" ]; then	# jeśli użytkownik nie podał parametrów, odeślij do usage
	usage
	exit 1
fi
page="$1"	# pobieramy stronę z parametru pierwszego
period="$2"	# pobieramy zakres czasu z parametru drugiego
url="https://a2.wykop.pl/Entries/Hot/page/$page/period/$period/appkey/$appkey/token/$token/userkey/$userkey/"
sign
if [ "$3" != "-s" ]; then	# jako trzeci parametr możemy dodać "-s", co wyciszy nagłówek
	printf "%b" "ID\t\t" "Date - time\t" "Votes\n"	# jeśli parametru -s nie ma, wyświetl nagłówek
fi
curl -s -H "apisign: $md5all" -X GET "$url" | grep -oP '((?<="id":)[^,]*|(?<="date":")[^"]*|(?<="vote_count":)[^,]*)' | sed 's/$/ /g' | awk 'ORS=NR%3?FS:RS'	# pobieramy i wyciągamy potrzebne dane, wyświetlamy w trzech kolumnach

exit 0
}


login() {	# funkcja logująca użytkownika i dorzucająca userkey do configu
if [ -s "$HOME/.config/mirkobash/login.conf" ]; then	# jeśli użytkownik wprowadził tam swoje dane logowania, wykorzystamy je
	. "$HOME/.config/mirkobash/login.conf"
else		# jeśli nie, pytamy użytkownika o login i hasło
	echo "Enter login:"
	read -s LOGIN
	echo "Enter password:"
	read -s PASSWORD
fi

url="https://a2.wykop.pl/Login/Index/accountkey/$token/appkey/$appkey/"
data="login=$LOGIN&password=$PASSWORD&accountkey=$token"
data2="$LOGIN,$PASSWORD,$token"
sign
newuserkey=$(curl -s -H "apisign: $md5all" -X POST --data "$data" "$url" | grep -oP '(?<="userkey":")[^"]*')	# wyciągamy nowy userkey
if [ -z "$newuserkey" ]; then	# jeśli curl nie zwróci userkey, wyświetlamy że był błąd
	echo "Error during login"
	exit 1
else
	sed -i 's/^userkey=".*"/userkey="'"$newuserkey"'"/' "$HOME/.config/mirkobash/mirkobash.conf"	# a jeśli zwrócił, to wrzucamy nowy klucz do configu
	echo "Logged in successfully"
	exit 0
fi
}


post() {	# funkcja pozwalająca na zapostowanie tekstu na mirko
if [ -z "$1" ]; then usage; fi

tresc="$1"	# pierwszy parametr to treść postu - musi być podany w cudzysłowiu
data="body=$tresc"
data2="$tresc"
url="https://a2.wykop.pl/entries/add/appkey/$appkey/token/$token/userkey/$userkey/"
sign

response=$(curl -s -H "apisign: $md5all" -X POST --data "$data" "$url")	# generalnie pobieramy info czy się udało, czy wystąpił błąd

if grep -q "error\":" <<< "$response"; then	# jeśli wyłapiemy błąd, należy o tym poinformować użytkownika
        errorcode=$(grep -oP '(?<="code":)[^,]*' <<< "$response")
        errormsg_en=$(grep -oP '(?<="message_en":")[^"]*' <<< "$response")
        errormsg_pl=$(grep -oP '(?<="message_pl":")[^"]*' <<< "$response")
        printf "%b\n" "Wystąpił błąd!" "Kod błędu: $errorcode" "Treść błędu (en): $errormsg_en" "Treść błędu: $errormsg_pl"
	exit "$errorcode"
else		# jeśli nie ma błędu - zwróć okejkę
        echo "Done :)"
	exit 0
fi
}

main "$@"	# po załadowaniu wszystkich configów etc, przenosimy użytkownika do ustalania jaki parametr wpisał
exit 2	# na wszelki wypadek, gdyby użytkownik przypadkiem opuścił ifa
