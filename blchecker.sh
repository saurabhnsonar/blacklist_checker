#/bin/bash

##script requires: 
##dig 
##mail server with mail function (if chosen use_smtp="0")
##mailx (if chosen use_smtp="1")

#If this is set to 1 then each subnet will be checked seperated (each subnet checking function will be sent to background)
run_in_background=1

#how many backgroundds start (in other words how many subnest will be checked instantly)
how_many_jobs=5

#If this is set to 1 you can have more then one subnets file and when first subnets file will be finished it will start second one
#subnets files names must start same as in (sub=subnets) variable but with different ending
#for example subnets1 subnets2 subnets3
all_subnets_files=1

#DNS server (some times own DNS server can check queryes slower so you want to enter an dns server manualy) leave it empty if you want to use your own dns server
dnsserver=

#File name where subnets are stored
sub=subnets

#blacklists list
listas=list

#show only blocked ips
show_only_blocked=1

#sleep between subnets
ssub=2s
#sleep between each ip is checked
sip=0.1s
#sleep between each blacklist check
sblck=0.001s
#Email to witch one it will send blacklisted ip
EMAIL="info@email.com"
#Send email after each subnet check 1 = yes; 0 =  email will be send instantly after blaclist found
semail=1

#prompter, if 1 then in email will be included removal link from file prompter
prompter=1
prompter_phone=111111
prompter_email=$EMAIL #you can enter any other email if you want


use_smtp="1" # requires package mailx if 1 then emails will be sent via smtp if 0 via mail server
smtp_srv="smt.server.com"
smtp_port="25"
smtp_user="smtp_user@server.com"
smtp_password="smtp_password"
smtp_from="no-replay@server.com"
smtp_sender_name="Your company"
smtp_ssl_args=(-S smtp-use-starttls -S nss-config-dir=/etc/pki/nssdb/ -S ssl-verify=ignore)

#If you want to use web interface please confogure options below
#to use web interface you need LAMP, LEMP (web server, database server (mysql, mariadb) and php witch one supports PDO)
#you need to upload www/blacklist content to web server webdir (it can be different depending on your OS, but it will be one of these:
#/var/www
#/var/html/www
#/var/html)
#also you need to upload to mysql server database.sql file (before doing this dont forget to create database)
#and last think is to configure options below

script_use_database=0 # if 0 script will not use database to store all information if 1 it will store all collected data to mysql (dont forget to create database for it, database file can be found www/blacklist/database.sql)
script_recheck_from_db_h=23 # after what time blacklisted ips in database will be rechecked (time in hours)
script_database_ip="localhost"
script_database_login="root"
script_database_password="secret"
script_database_name="blacklist"

#This is only example how you can modify this script to send information about blacklisted ips directly to your clients
#you must modyfi DATABASE queryes to get correct information about client if you want to use it
#i have added only example of database queryes
#also you must install database client in server from witch one this script will run
#because of all requirements i posted by default this function is turned off and you must it turn on only when you know what are you doing
#in my example i`m using mysql/mariadb database if you are using an other you must change database client in script
#you can find all my example queryes by entering in search "$notify_database_login"

user_notify=0
user_notify_test=1 #if 1 = enabled if enabled then it will send email to your specified email address
user_notify_test_email=$EMAIL #you can setup test email
notify_database_ip="localhost"
notify_database_login="root"
notify_database_password="secret"
notify_database_name="an_database"


#for crontabs we need to know where script is placed
workdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#lest make shorted mysql connect arguments
script_database_mysql=(-u$script_database_login -h$script_database_ip -p$script_database_password $script_database_name)
notify_database_mysql=(-u$notify_database_login -h$notify_database_ip -p$notify_database_password $notify_database_name)

#Possibillity to add variables from CLI
#For example:
#bash blchecker -l custom_blacklists -s subnets2-3 -n "blacklist checker" -e test4@test.test
# -l variable for blacklists list file from cli
# -s variable for subnets list file from cli
# -n variable for smtp sender name from cli
# -e variable for email from cli
while getopts l:s:n:e: option
do
 case "${option}"
 in
 l) listas=${OPTARG};;
 s) sub=${OPTARG};;
 n) smtp_sender_name=${OPTARG};;
 e) EMAIL=${OPTARG};;
 esac
done

if [ "$semail" = 1  ]; then
	declare -a mailarr
fi

#check ip function
checkip_f () {
    if [ -z "$dnsserver"  ]; then
        dig +short $1.$2 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep 127.0.* | head -n 1
    else
        dig +short @$dnsserver $1.$2 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep 127.0.* | head -n 1
    fi
}

#reverse ip function
reverseip_f () {
	local IFS
	IFS=.
	set -- $1
	echo $4.$3.$2.$1
}

#recheck blacklisted ips from database function
#check_curent_records_in_db_f () {
#    local script_database_blocked
#    local IFS
#    local script_ip
#    local script_blacklist
#    local script_ip_reverse
#    local script_res
#    script_database_blocked=`echo "SELECT ip, listName FROM ips_blacked WHERE ip LIKE '$1' AND recheck <= DATE_SUB(NOW(), INTERVAL $script_recheck_from_db_h HOUR);" | mysql -N "${script_database_mysql[@]}"`
#    IFS=$'\n'
#    for script_result in $script_database_blocked
#    do
#        script_ip=`echo $script_result | awk {'print $1'}`
#        script_blacklist=`echo $script_result | awk {'print $2'}`
#        script_ip_reverse=$(reverseip_f $script_ip)
#        script_res=$(checkip_f $script_ip_reverse $script_blacklist)
#        if [ -z "$script_res"  ]; then
#            echo "DELETE FROM ips_blacked WHERE ip LIKE '$script_ip' AND listName LIKE '$script_blacklist';" | mysql "${script_database_mysql[@]}"
#            echo "INSERT INTO ips_history (ip, date, action) VALUES ('$script_ip', Now(), 'Removed $script_blacklist');" | mysql "${script_database_mysql[@]}"
#        fi
#    done
#}

prompter_f () {
	rez_prompter=`cat $workdir/prompter | grep -v "#" | grep $1 | head -n 1 | awk '{print $2}' |  sed "s/{{ip}}/$3/g" | sed "s/{{phone}}/$prompter_phone/g" | sed "s/{{email}}/$prompter_email/g"`
	if [ ! -z "$rez_prompter"  ]; then
		EMAILMESSAGE=`echo "ip $3 blacklisted on $1 list - gotten result $2\n$rez_prompter\n\n"`
	else
		EMAILMESSAGE=`echo "ip $3 blacklisted on $1 list - gotten result $2\n\n"`
	fi
}

sendemail_f () {
	if [ "$semail" = 0  ]; then
		if [ "$use_smtp" = 1  ]; then
			echo -e $EMAILMESSAGE | mailx -s "BLACKLISTED ips $i1" "${smtp_ssl_args[@]}" -S smtp=smtp://$smtp_srv:$smtp_port -S smtp-auth=login -S smtp-auth-user=$smtp_user -S smtp-auth-password=$smtp_password -S from="$smtp_sender_name <$smtp_from>" $EMAIL
		else
			echo -e $EMAILMESSAGE | mail -s "BLACKLISTED ips $i1" "$EMAIL"
		fi   
	else
		mailarr+=($EMAILMESSAGE)
	fi
}

user_notify_f () {
    #users notification about blocked ips
    #database query to get or ip is actyve (only in my system there is lis of actyve or no ips list thats why i have comented it out)
    user_ip_used=`echo "SELECT ROW_WHERE_INFO_OF_IP_USED FROM IPS_TABLE WHERE ROW_IPS LIKE '$i1.$i2';" | mysql -N "${notify_database_mysql[@]}"`
    if [ "$user_ip_used" = 1  ]; then # answer from db in your system may be different or it dos not exists in your system and it is only example
        #lets check who own ip
        #getting orderid
        user_order_id=`echo "SELECT ORDER_ID FROM IPS_TABLE WHERE ROW_IPS LIKE '$i1.$i2';" | mysql -N "${notify_database_mysql[@]}"`
        if [ "$user_order_id" = 0  ]; then
            if [ "$script_use_database" = 1 ]; then
                user_email=""
            fi
        else
            #geting clientid
			user_client_id=`echo "SELECT CLIENT_ID FROM YOUR_ORDERS WHERE ID LIKE '$user_order_id';" | mysql -N "${notify_database_mysql[@]}"`
			#geting user data witch one we will use to send email notification about blocked ip
			user_client_data=`echo "SELECT FIRST_NAME,LAST_NAME,EMAIL,USER_LANGUAGE FROM CLIENTS_TABLE WHERE id LIKE '$user_client_id';" | mysql -N "${notify_database_mysql[@]}"`
			user_language=`echo $user_client_data | awk '{print $4}'`
			user_f_name=`echo $user_client_data | awk '{print $1}'`
			user_l_name=`echo $user_client_data | awk '{print $2}'`
			user_email=`echo $user_client_data | grep -E -o "\b[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b"`
			user_rez_prompter=`cat $workdir/prompter | grep -v "#" | grep $l | head -n 1 | awk '{print $2}' |  sed "s/{{ip}}/$i1.$i2/g" | sed "s/{{phone}}/$prompter_phone/g" | sed "s/{{email}}/$user_email/g"`
			#now lets generate few different types of messages because in my system there is more then one language
			if [ "$user_language" = en  ]; then
				user_subject="Your server ip address is blacklisted"
				USER_EMAILMESSAGE="Hello $user_f_name $user_l_name,\n\nWe have detected that one of yours server ip address $i1.$i2 have been blacklisted in $l.\nPlease remove blacklist as soon as it possible - to do it please follow link below\n$user_rez_prompter\n\nThank you.\n\n--\n\nRegards,\nYOUR_ORGANIZATION Administration"
			elif [ "$user_language" = lt  ]; then
				user_subject="Jusu serverio ip adresas yra blacklistintas"
				USER_EMAILMESSAGE="Sveiki $user_f_name $user_l_name,\n\nAptikome, kad vienas iš jusu serverio ip adresu $i1.$i2 yra blokuojamas $l blackliste.\nPrašome pašalinti blacklista kaip imanoma greiciau - informacija kaip tai padaryti rasite nuorodoje žemiau\n$user_rez_prompter\n\nDekojame.\n\n--\n\nPagarbiai,\nYOUR_ORGANIZATION Administracija"
			else
				user_subject="Your server ip address is blacklisted"
				USER_EMAILMESSAGE="Hello $user_f_name $user_l_name,\n\nWe have detected that one of yurs server ip address $i1.$i2 have been blacklisted in $l.\nPlease remove blacklist as soon as it possible - to do it please follow link below\n$user_rez_prompter\n\nThank you.\n\n--\n\nRegards,\nYOUR_ORGANIZATION Administration"
			fi
				#lets send notification to users
				#we wont send notifications until we have tested it
				if [ "$user_notify_test" = 1  ]; then
					if [ "$use_smtp" = 1  ]; then
						echo -e "$user_email $USER_EMAILMESSAGE" | mailx -s "$user_subject" "${smtp_ssl_args[@]}" -S smtp=smtp://$smtp_srv:$smtp_port -S smtp-auth=login -S smtp-auth-user=$smtp_user -S smtp-auth-password=$smtp_password -S from="$smtp_sender_name <$smtp_from>" $user_notify_test_email
					else
						echo -e "$user_email $USER_EMAILMESSAGE" | mail -s "$user_subject" $user_notify_test_email
					fi
				else
					if [ "$use_smtp" = 1  ]; then
						echo -e $USER_EMAILMESSAGE | mailx -s "$user_subject" "${smtp_ssl_args[@]}" -S smtp=smtp://$smtp_srv:$smtp_port -S smtp-auth=login -S smtp-auth-user=$smtp_user -S smtp-auth-password=$smtp_password -S from="$smtp_sender_name <$smtp_from>" $user_email
					else
						echo -e $USER_EMAILMESSAGE | mail -s "$user_subject" $user_email
					fi

				fi
			else
                if [ "$script_use_database" = 1 ]; then
                    user_email=""
                fi

            fi
        fi
    else
        if [ "$script_use_database" = 1 ]; then
            user_email=""
        fi
    fi
}


use_database_f () {
    script_or_blacklisted=`echo "SELECT ip, userID FROM ips_blacked WHERE ip LIKE '$1' AND listName LIKE '$2';" | mysql -N "${script_database_mysql[@]}"`
    if [ -z "$script_or_blacklisted"  ]; then
        if [ "$prompter" = 1  ]; then
            if [ "$user_notify" = 1  ]; then
                echo "INSERT INTO ips_blacked (ip, userID, url, listName, date, recheck) VALUES ('$1', '$user_email', '$rez_prompter', '$2', Now(), Now());" | mysql "${script_database_mysql[@]}"
                echo "INSERT INTO ips_history (ip, date, action, userID) VALUES ('$1', Now(), 'Added $2', '$user_email');" | mysql "${script_database_mysql[@]}"
            else
                echo "INSERT INTO ips_blacked (ip, url, listName, date, recheck) VALUES ('$1', '$rez_prompter', '$2', Now(), Now());" | mysql "${script_database_mysql[@]}"
                echo "INSERT INTO ips_history (ip, date, action) VALUES ('$1', Now(), 'Added $2');" | mysql "${script_database_mysql[@]}"
            fi
        else
            echo "INSERT INTO ips_blacked (ip, listName, date, recheck) VALUES ('$1', '$2', Now(), Now());" | mysql "${script_database_mysql[@]}"
            echo "INSERT INTO ips_history (ip, date, action) VALUES ('$1', Now(), 'Added $2');" | mysql "${script_database_mysql[@]}"
        fi
    else
        if [ "$user_notify" = 1  ]; then
            local curent_user
            curent_user=`echo $script_or_blacklisted | awk {'print $2'}`
            if [ "$user_email" = "$curent_user" ]; then
                echo "UPDATE ips_blacked SET recheck=Now() WHERE ip LIKE '$1' AND listName LIKE '$2';" | mysql "${script_database_mysql[@]}"
            else
                echo "UPDATE ips_blacked SET userID='$user_email', date=Now(), recheck=Now() WHERE ip LIKE '$1' AND listName LIKE '$2';" | mysql "${script_database_mysql[@]}"
                echo "INSERT INTO ips_history (ip, date, action, userID) VALUES ('$1', Now(), 'User changed from $curent_user to $user_email, still listed in $2', '$user_email');" | mysql "${script_database_mysql[@]}"
            fi
        else
            echo "UPDATE ips_blacked SET recheck=Now() WHERE ip LIKE '$1' AND listName LIKE '$2';" | mysql "${script_database_mysql[@]}"
        fi
    fi
}

lets_go_f () {
	res=$(checkip_f $1 $3)
	if [ ! -z "$res"  ]; then
		if [ "$prompter" = 1  ]; then
			prompter_f $3 $res $2
		else
			EMAILMESSAGE=`echo "ip $2 blacklisted on $3 list - gotten result $res\n"`
		fi
		if [ ! -z "$EMAIL"  ]; then #do not send email if dont want it
			sendemail_f $4
		fi
		if [ "$user_notify" = 1  ]; then
			user_notify_f
		fi
		if [ "$script_use_database" = 1 ]; then
			use_database_f $2 $3
		fi
		echo "ip $2 blacklisted on $3 list - gotten result $res"
	else
		if [ "$script_use_database" = 1 ]; then
			check_or_need_remove=`echo "SELECT ip FROM ips_blacked WHERE ip LIKE '$2' AND listName LIKE '$3';" | mysql -N "${script_database_mysql[@]}"`
			if [ ! -z "$check_or_need_remove" ]; then
				echo "DELETE FROM ips_blacked WHERE ip LIKE '$2' AND listName LIKE '$3';" | mysql "${script_database_mysql[@]}"
				echo "INSERT INTO ips_history (ip, date, action) VALUES ('$2', Now(), 'Removed $3');" | mysql "${script_database_mysql[@]}"
			fi
		fi
		if [ "$show_only_blocked" = 0 ]; then
			echo "ip $2 not blacklisted on $3 list - gotten result $res"
		fi
	fi

}

main_control_f () {
	i1=$1
	i2=$2
	i3=$3
        while [[ $i2 -le $i3 ]]
        do
                ip=$(reverseip_f $i1.$i2)
                for l in $(cat $workdir/$listas | grep -v "#")
                do
                        if [ "$script_use_database" = 1 ]; then
                                script_ip_curent_exists=`echo "SELECT ip, listName FROM ips_blacked WHERE ip LIKE '$i1.$i2' AND listName LIKE '$l';" | mysql -N "${script_database_mysql[@]}"`
                                if [ ! -z "$script_ip_curent_exists" ]; then
                                        script_ip_curent_listed=`echo "SELECT ip, listName FROM ips_blacked WHERE ip LIKE '$i1.$i2' AND listName LIKE '$l' AND recheck < DATE_SUB(NOW(), INTERVAL $script_recheck_from_db_h HOUR);" | mysql -N "${script_database_mysql[@]}"`
                                        if [ ! -z "$script_ip_curent_listed" ]; then
                                                lets_go_f $ip $i1.$i2 $l $i1
                                        else
                                                echo "IP: $i1.$i2 is curently listed in $l and it is no time to check it again"
                                        fi
                                else
                                        lets_go_f $ip $i1.$i2 $l $i1
                                fi
                        else
                                lets_go_f $ip $i1.$i2 $l $i1
                        fi
                done
                ((i2 = i2 + 1))
                sleep $sip
        done
        if [ "$semail" = 1  ]; then
                if [ -z "$mailarr" ]; then
                        echo "Array empty"
                else
                        if [ "$use_smtp" = 1  ]; then
                                echo -e  ${mailarr[*]} | mailx -s "BLACKLISTED ips $i1" "${smtp_ssl_args[@]}" -S smtp=smtp://$smtp_srv:$smtp_port -S smtp-auth=login -S smtp-auth-user=$smtp_user -S smtp-auth-password=$smtp_password -S from="$smtp_sender_name <$smtp_from>" $EMAIL
                        else
                                echo -e  ${mailarr[*]} | mail -s "BLACKLISTED ips $i1" "$EMAIL"
                        fi
                fi
		if [ "$run_in_background" = 0 ]; then
                	unset mailarr
		fi
        fi
}

clear
echo ""
echo ""
echo "IP blacklist checker"
echo "You can configure script seting up variables inside script"
echo "Or you can set some parameters directly runing script"
echo "These parameters are:"
echo "You can use not all parameters, for example you can use only -s subnets2 - then all other parameters will be taken from inside of script"
echo ""
echo "   -l - file where stored blacklists"
echo "   -s - file where stored subnets"
echo "   -n - SMTP sender name"
echo "   -e - Email to what blacked ips will be sent"
echo ""
echo ""
echo "Blacklist checking process started with folowing configuration:"
echo ""
echo "Or blacklist checking will run in background: $run_in_background"
echo "Or script will use all subnets files:         $all_subnets_files"
echo "Blacklists file:                              $listas"
if [ "$all_subnets_files" = 1 ]; then
	subecho=`ls $workdir/ | grep subnets`
	echo "Subnets file:                                 $subecho"
else
	echo "Subnets file:                                 $sub"
fi
echo "Email what will get blocked ips:              $EMAIL"
echo "Show only blocked ips:                        $show_only_blocked"
echo "Will we use SMTP?:                            $use_smtp"
echo "SMTP sender name:                             $smtp_sender_name"
echo "SMTP server:                                  $smtp_srv"
echo "SMTP port:                                    $smtp_port"
echo "SMTP username:                                $smtp_user"
echo "SMTP from:                                    $smtp_from"
echo "Will we use prompter:                         $prompter"
echo "Will we use database:                         $script_use_database"
echo "After what time recheck ips from database:    $script_recheck_from_db_h hours"
echo "Will we use user notification:                $user_notify"
echo "User notifications test enabled:              $user_notify_test"
echo "Script working directory:                     $workdir"
echo "DNS server used by script:                    $dnsserver"
echo "Sleep betwen each subnets check:              $ssub"
echo "Sleep betwen each ip check:                   $sip"
echo "Sleep betwen each blacklist check:            $sblck"
echo "Will script use array to send emails:         $semail"


if [ "$all_subnets_files" = 1 ]; then
        for subnet_files in $(ls $workdir/$sub*)
        do
                while read i;
                do
                        i1=`echo $i | awk '{print $1}'`
                        i2=`echo $i | awk '{print $2}'`
                        i3=`echo $i | awk '{print $3}'`
                        if [ "$run_in_background" = 1 ]; then
                                runing_jobs=`jobs | wc -l`
                                if [ "$runing_jobs" -lt "$how_many_jobs" ]; then
                                        main_control_f $i1 $i2 $i3 &
					echo "Subnet $i1 $i2 $i3 started to check in background"
                                else
                                        while [ $runing_jobs -ge $how_many_jobs ]
                                        do
                                                sleep 5
                                                runing_jobs=`jobs | wc -l`
                                        done
                                        main_control_f $i1 $i2 $i3 &
					echo "Subnet $i1 $i2 $i3 started to check in background"
                                fi
                        else
				echo "Subnet $i1 $i2 $i3 started to check"
                                main_control_f $i1 $i2 $i3
                                sleep $ssub
                        fi
                done <$subnet_files
                if [ "$run_in_background" = 1 ]; then
                        unset mailarr
                fi
        done
else
        while read i;
        do
                i1=`echo $i | awk '{print $1}'`
                i2=`echo $i | awk '{print $2}'`
                i3=`echo $i | awk '{print $3}'`
                if [ "$run_in_background" = 1 ]; then
                        runing_jobs=`jobs | wc -l`
                        if [ "$runing_jobs" -lt "$how_many_jobs" ]; then
                                main_control_f $i1 $i2 $i3 &
                                echo "Subnet $i1 $i2 $i3 started to check in background"
                        else
                                while [ $runing_jobs -ge $how_many_jobs ]
                                do
                                        sleep 5
                                        runing_jobs=`jobs | wc -l`
                                done
                                main_control_f $i1 $i2 $i3 &
                                echo "Subnet $i1 $i2 $i3 started to check in background"
                        fi
                else
			echo "Subnet $i1 $i2 $i3 started to check"
                        main_control_f $i1 $i2 $i3
                        sleep $ssub
                fi
        done <$workdir/$sub
fi


